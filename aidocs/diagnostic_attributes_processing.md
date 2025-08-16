## Summary of Diagnostic Attribute Processing

The main code paths for processing diagnostic attributes are:

### 1. **Attribute Definitions** - `/compiler/rustc_feature/src/builtin_attrs.rs:505-545`
   - Defines the five diagnostic attributes as ungated, normal attributes that can appear multiple times

### 2. **Level Parsing** - `/compiler/rustc_lint_defs/src/lib.rs:250-277`
   - `Level::from_attr()` and `Level::from_symbol()` convert attribute names to lint levels
   - Maps `sym::allow`, `sym::warn`, `sym::deny`, `sym::forbid`, `sym::expect` to their respective levels

### 3. **AST Lowering & Storage** - `/compiler/rustc_ast_lowering/src/lib.rs`
   - `lower_attrs()` at line 941-970 converts AST attributes to HIR attributes
   - Attributes are stored in `AttributeMap` for each HIR owner

### 4. **Traversal & Application** - `/compiler/rustc_lint/src/levels.rs`
   - **Main entry**: `shallow_lint_levels_on()` at line 160-203 processes attributes for an owner
   - **HIR Visitor**: Lines 277-348 implement `Visitor` that calls `add_id()` for each HIR node
   - **`add_id()`**: Line 267-274 processes attributes for a specific HIR node
   - **`add()`**: Line 639-908 is the core method that:
     - Extracts lint level from attributes (line 676)
     - Parses lint names and reasons from meta items (lines 741-900)
     - Calls `insert_spec()` to apply the level (line 877)

### 5. **Level Storage & Propagation** - `/compiler/rustc_lint/src/levels.rs`
   - **`insert_spec()`**: Lines 544-636 enforces precedence rules (forbid > deny > warn > allow)
   - **`LintLevelSets`**: Lines 47-117 maintains a linked list of lint specifications
   - **`LintLevelSource`**: Defined in `/compiler/rustc_middle/src/lint.rs:18-50` tracks where a level came from

### 6. **Attribute Recognition** - `/compiler/rustc_ast/src/attr/mod.rs`
   - `AttributeExt` trait (lines 750-833) provides `name()` and `has_name()` methods
   - Used to identify diagnostic attributes by comparing against symbols

### 7. **Command-line Integration** - `/compiler/rustc_lint/src/levels.rs:471-539`
   - `add_command_line()` processes `-A`, `-W`, `-D`, `-F` flags
   - Creates `LintLevelSource::CommandLine` entries

### 8. **Query System** - `/compiler/rustc_middle/src/query/mod.rs:275`
   - `hir_attr_map` query provides attributes for HIR owners
   - `shallow_lint_levels_on` query computes lint levels per owner

The flow is: AST attributes → HIR attributes → stored in `AttributeMap` → traversed by visitor → parsed by `add()` → levels stored in `LintLevelSets` → applied to lints during compilation.

