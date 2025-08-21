# Proc Macro Diagnostic Attributes Investigation Log

## Goal and Purpose

This file serves as a comprehensive log to track the investigation and resolution of the issue where diagnostic attributes (`#[expect]`, `#[allow]`, etc.) don't work on proc macro attributes. The purpose is to:

1. **Document findings** from our investigation
2. **Track progress** on implementing solutions
3. **Record what worked and what didn't** during the debugging process
4. **Provide context** for future maintainers working on this issue
5. **Establish a clear path forward** for implementing the fix

## Issue Description

**Problem**: Diagnostic attributes like `#[expect(clippy::disallowed_macros)]` and `#[allow(clippy::disallowed_macros)]` are not being respected when applied to items that use proc macro attributes.

**Example**:
```rust
#[expect(clippy::disallowed_macros)]
#[macrolib::attrib_macro]  // This should be suppressed but isn't
fn foo() {}
```

**Expected behavior**: The `#[expect]` attribute should suppress the `disallowed_macros` lint for the proc macro usage.

**Actual behavior**: The lint is still emitted despite the `#[expect]` attribute.

## Investigation Findings

### Root Cause Analysis

**Confirmed Issue**: The problem occurs because lint level checking happens on the **expanded code's HIR node** instead of the **original item's HIR node** that contains the diagnostic attributes.

**Evidence from Debug Output**:

1. **Working case** (module-level `#[expect]`):
   ```
   Current HIR ID: HirId(DefId(0:3 ~ test_crate[eb4b]::bar).0)
   Lint level: Expect
   ```

2. **Broken case** (item-level `#[expect]`):
   ```
   Current HIR ID: HirId(DefId(0:6 ~ test_crate[eb4b]::foo).0)
   Lint level: Warn  // Should be Expect!
   ```

**Key Insight**: The `last_node_with_lint_attrs` field in `LateContext` points to the expanded code's HIR node, not the original node with the `#[expect]` attribute.

### Code Analysis

**Files Modified**:
- `compiler/rustc_lint/src/context.rs`: Added debug logging to `get_lint_level` method
- `src/tools/clippy/clippy_lints/src/disallowed_macros.rs`: Added debug logging to `check` method

**Key Methods Involved**:
- `get_lint_level()`: Determines lint level for a given lint
- `hir_parent_id_iter()`: Walks up the HIR tree (available and working)
- `span.from_expansion()`: Detects macro expansion context (available and working)
- `outer_expn_data()`: Gets expansion details (available and working)

## Proposed Solution

### Solution 1: Modify Lint Level Resolution for Proc Macros (Recommended)

**Location**: `compiler/rustc_lint/src/context.rs`

**Implementation Plan**:
1. Enhance `get_lint_level()` to detect proc macro expansion context
2. When in proc macro expansion, walk up HIR tree using `hir_parent_id_iter()`
3. Find the original node that has the diagnostic attributes
4. Use that node's attributes for lint level determination

**Code Structure**:
```rust
fn get_lint_level(&self, lint: &'static Lint) -> LevelAndSource {
    let mut current_id = self.last_node_with_lint_attrs;
    
    // Check if we're in a proc macro expansion
    if self.is_in_proc_macro_expansion(current_id) {
        // Walk up the HIR tree to find the original node
        if let Some(original_id) = self.find_original_node_with_attrs(current_id) {
            current_id = original_id;
        }
    }
    
    self.tcx.lint_level_at_node(lint, current_id)
}
```

**Helper Methods Needed**:
- `is_in_proc_macro_expansion()`: Detect `ExpnKind::Macro(MacroKind::Attr, _)`
- `find_original_node_with_attrs()`: Walk HIR tree using `hir_parent_id_iter()`

## Progress Made

### ✅ Completed:
- **Issue reproduction**: Confirmed the bug exists
- **Root cause identification**: Found that lint level checking uses wrong HIR node
- **Debug infrastructure**: Added comprehensive logging to both `get_lint_level` and `disallowed_macros` lint
- **API verification**: Confirmed all needed methods exist and work correctly
- **Solution design**: Designed Solution 1 with specific implementation details

### 🔄 In Progress:
- **Solution implementation**: Ready to implement Solution 1
- **Testing**: Need to implement and test the fix

### ❌ Not Yet Done:
- **Actual fix implementation**: The core logic changes haven't been made yet
- **Testing with fix**: Need to verify the solution works
- **Edge case handling**: Need to test various scenarios

## Next Steps

1. **Implement Solution 1**:
   - Add helper methods to `LateContext`
   - Modify `get_lint_level()` to handle proc macro expansions
   - Test the fix with the repro

2. **Test Edge Cases**:
   - Nested proc macro expansions
   - Mixed macro and proc macro usage
   - Different types of diagnostic attributes

3. **Performance Analysis**:
   - Ensure the HIR tree walking doesn't cause performance issues
   - Consider caching strategies if needed

## Files to Monitor

- `repro/src/lib.rs`: Test cases for the issue
- `compiler/rustc_lint/src/context.rs`: Where the fix will be implemented
- `src/tools/clippy/clippy_lints/src/disallowed_macros.rs`: Lint implementation (for reference)

## Success Criteria

The fix is successful when:
1. `#[expect(clippy::disallowed_macros)]` works on items with proc macro attributes
2. `#[allow(clippy::disallowed_macros)]` works on items with proc macro attributes
3. No performance regression in lint checking
4. All existing functionality continues to work

---

**Last Updated**: 2025-01-21
**Status**: Investigation complete, ready for implementation