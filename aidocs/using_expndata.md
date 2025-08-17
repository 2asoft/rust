# ExpnData Approach for Preserving Diagnostic Attributes Through Macro Expansion

## **Problem**
Proc macros consume diagnostic attributes (`#[allow]`, `#[warn]`, `#[deny]`, `#[forbid]`, `#[expect]`), making them unavailable for lint resolution on expanded code. The attributes are removed from the AST before the proc macro sees the tokens, and the expanded code has no knowledge of the original diagnostic intentions.

## **Solution: Store Diagnostic Attributes in ExpnData**

### **1. Add Field to ExpnData**
Location: `rustc_span/src/hygiene.rs:983` (struct ExpnData)
```rust
pub struct ExpnData {
    pub kind: ExpnKind,
    pub parent: ExpnId,
    pub call_site: Span,
    disambiguator: u32,
    pub def_site: Span,
    pub allow_internal_unstable: Option<Arc<[Symbol]>>,
    pub edition: Edition,
    pub macro_def_id: Option<DefId>,
    pub parent_module: Option<DefId>,
    pub(crate) allow_internal_unsafe: bool,
    pub local_inner_macros: bool,
    pub(crate) collapse_debuginfo: bool,
    pub hide_backtrace: bool,
    // ADD THIS:
    pub diagnostic_attrs: Option<Arc<FxHashMap<LintId, LevelAndSource>>>,
}
```

Also update `ExpnData::default` and `ExpnData::new` constructors to initialize this field to `None`.

### **2. Capture Diagnostic Attributes Before They're Lost**

**Location**: `rustc_expand/src/expand.rs:2066-2114` (in `take_first_attr` function)

Current code removes the proc macro attribute around line 2092:
```rust
let attr = item.attrs_mut().remove(attr_pos);
```

**Before this line, add:**
```rust
// Extract diagnostic attributes before they're lost
let diagnostic_attrs = extract_diagnostic_attrs(item.attrs());
```

**New function to add** (in same file):
```rust
fn extract_diagnostic_attrs(attrs: &[ast::Attribute]) -> Option<Arc<FxHashMap<LintId, LevelAndSource>>> {
    let mut lint_levels = FxHashMap::default();
    
    for attr in attrs {
        // Check if this is a diagnostic attribute
        let Some(level) = attr.name().and_then(|name| match name {
            sym::allow => Some(Level::Allow),
            sym::warn => Some(Level::Warn),
            sym::deny => Some(Level::Deny),
            sym::forbid => Some(Level::Forbid),
            sym::expect => {
                // Handle expect with LintExpectationId
                // Use existing Level::from_attr logic
            }
            _ => None,
        }) else {
            continue;
        };
        
        // Parse the meta items to get lint names
        let Some(meta_items) = attr.meta_item_list() else {
            continue;
        };
        
        for meta_item in meta_items {
            // Extract lint name, handle tool prefixes (clippy::, rustc::)
            // Convert to LintId using store.find_lints() or similar
            // Handle reason strings if present
            // Create LevelAndSource and insert into map
        }
    }
    
    if lint_levels.is_empty() {
        None
    } else {
        Some(Arc::new(lint_levels))
    }
}
```

### **3. Pass Diagnostic Attributes to ExpnData**

**Location**: `rustc_expand/src/base.rs:1066` (in `SyntaxExtension::expn_data`)

Current code:
```rust
ExpnData::new(
    ExpnKind::Macro(kind, descr),
    parent.to_expn_id(),
    call_site,
    self.span,
    self.allow_internal_unstable.clone(),
    self.edition,
    macro_def_id,
    parent_module,
    self.allow_internal_unsafe,
    self.local_inner_macros,
    self.collapse_debuginfo,
    self.builtin_name.is_some(),
)
```

Modify to pass diagnostic_attrs as the last parameter (after updating ExpnData::new signature).

**Also need to thread diagnostic_attrs through:**
- `InvocationCollector::take_first_attr` needs to return diagnostic_attrs
- `InvocationCollector::expand_invoc` needs to receive and pass them
- Other ExpnData creation sites should pass `None` for backward compatibility

### **4. Check ExpnData During Lint Resolution**

**Location**: `rustc_middle/src/lint.rs:165-200` (in `lint_level_id_at_node`)

After the existing probe fails (around line 186):
```rust
let (level, mut src) = self.probe_for_lint_level(tcx, lint, cur);

// NEW: Check ExpnData for preserved diagnostic attributes
if matches!(src, LintLevelSource::Default) {
    let span = tcx.hir_span(cur);
    if span.from_expansion() {
        let expn_data = span.ctxt().outer_expn_data();
        if let Some(diagnostic_attrs) = &expn_data.diagnostic_attrs {
            if let Some(level_and_source) = diagnostic_attrs.get(&lint) {
                // Found preserved diagnostic attribute
                return *level_and_source;
            }
        }
    }
}

// Continue with existing reveal_actual_level logic...
```

## **Handling LintId Resolution**

**Challenge**: During expansion (AST phase), we don't have access to the LintStore to resolve lint names to LintIds.

**Solution Options**:
1. **Store as Symbols**: Store `FxHashMap<Symbol, (Level, Option<Symbol>)>` in ExpnData, resolve to LintId during lint checking
2. **Early Resolution**: Pass LintStore to expansion phase (more complex, changes phase ordering)
3. **Delayed Resolution**: Store raw attribute data, process during HIR lowering

**Recommended**: Option 1 - Store as Symbols, similar to how `allow_internal_unstable` stores `Arc<[Symbol]>`.

## **Updated ExpnData Field**:
```rust
// More practical implementation
pub diagnostic_attrs: Option<Arc<FxHashMap<Symbol, (Level, Option<Symbol>)>>>,
// Symbol -> (Level, Optional reason string)
```

## **Integration with Existing Infrastructure**

**LintLevelSource**: May need new variant:
```rust
pub enum LintLevelSource {
    Default,
    Node { name: Symbol, span: Span, reason: Option<Symbol> },
    CommandLine(Symbol, Level),
    // ADD:
    Expansion { name: Symbol, expn_id: ExpnId, reason: Option<Symbol> },
}
```

**Thread-local Recursion Guards**: The existing `RECURSION_GUARD` in lint resolution should be removed as it's no longer needed with ExpnData approach.

## **Testing Considerations**

The diagnostic attributes should work for:
- Proc macro attributes (`#[my_macro]`)
- Derive macros (`#[derive(MyDerive)]`)
- Function-like proc macros (though less common to have attributes)
- Built-in macros (should preserve existing behavior)

## **Precedent: `allow_internal_unstable`**

This follows the existing pattern where ExpnData preserves `allow_internal_unstable`:

**Already in ExpnData** (`rustc_span/src/hygiene.rs:1021`):
```rust
pub allow_internal_unstable: Option<Arc<[Symbol]>>,
```

**Extracted During Macro Registration** (`rustc_expand/src/base.rs:755`):
```rust
let allow_internal_unstable = attr::allow_internal_unstable(sess, attrs);
```

**Set During Expansion** (`rustc_expand/src/base.rs:1066`):
```rust
ExpnData::new(
    // ... parameters ...
    self.allow_internal_unstable.clone(),  // Semantic attrs preserved
)
```

**Used Later During Feature Checking** (`rustc_passes/src/stability.rs:900`):
```rust
if let Some(features) = expn_data.allow_internal_unstable {
    // Check if unstable feature is allowed
}
```

This proves ExpnData successfully carries semantic information through compilation phases, from macro expansion (early) to feature checking (late).

## **Key Files to Modify**
1. `rustc_span/src/hygiene.rs` - Add field to ExpnData struct, update constructors
2. `rustc_expand/src/expand.rs` - Extract diagnostic attrs in take_first_attr, add extraction function
3. `rustc_expand/src/base.rs` - Update ExpnData::new calls to pass diagnostic attrs
4. `rustc_middle/src/lint.rs` - Check ExpnData in lint_level_id_at_node
5. `rustc_lint_defs/src/lib.rs` - Possibly add new LintLevelSource variant

## **Cleanup from Previous Attempts**
Remove from the codebase:
- `find_hir_id_by_span` function in `rustc_middle/src/hir/map.rs`
- `probe_callsite_lint_level` function in `rustc_middle/src/lint.rs`
- Thread-local recursion guards in lint resolution
- Two-phase resolution implementation in `lint_level_id_at_node`

