// RYZ AST node definitions.
export type Node =
  | Program | FnDecl | Param | LetStmt | ReturnStmt | IfStmt | WhileStmt
  | ExprStmt | ImportStmt | DeferStmt | Block
  | IntLit | FloatLit | StrLit | BoolLit | Ident
  | Binary | Unary | Call | Member | Assign;

export interface Program { kind: "Program"; body: Node[]; }
export interface Param { kind: "Param"; name: string; type?: string; }
export interface FnDecl { kind: "FnDecl"; name: string; params: Param[]; retType?: string; body: Block; exported: boolean; }
export interface Block { kind: "Block"; body: Node[]; }
export interface LetStmt { kind: "LetStmt"; name: string; mutable: boolean; type?: string; value: Node; }
export interface ReturnStmt { kind: "ReturnStmt"; value?: Node; }
export interface IfStmt { kind: "IfStmt"; cond: Node; then: Block; else?: Block | IfStmt; }
export interface WhileStmt { kind: "WhileStmt"; cond: Node; body: Block; }
export interface ExprStmt { kind: "ExprStmt"; expr: Node; }
export interface ImportStmt { kind: "ImportStmt"; path: string; }
export interface DeferStmt { kind: "DeferStmt"; expr: Node; }

export interface IntLit { kind: "IntLit"; value: number; }
export interface FloatLit { kind: "FloatLit"; value: number; }
export interface StrLit { kind: "StrLit"; value: string; }
export interface BoolLit { kind: "BoolLit"; value: boolean; }
export interface Ident { kind: "Ident"; name: string; }
export interface Binary { kind: "Binary"; op: string; left: Node; right: Node; }
export interface Unary { kind: "Unary"; op: string; operand: Node; }
export interface Call { kind: "Call"; callee: Node; args: Node[]; }
export interface Member { kind: "Member"; object: Node; property: string; }
export interface Assign { kind: "Assign"; target: Node; value: Node; }
