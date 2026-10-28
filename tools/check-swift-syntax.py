"""Optional Linux syntax check; NOT Swift type checking or an iOS build.
Dependencies: tree-sitter==0.25.2, tree-sitter-swift==0.0.1.
"""
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_swift
parser=Parser(Language(tree_sitter_swift.language()))
failed=False
for p in (Path(__file__).resolve().parents[1]/'ios').rglob('*.swift'):
 tree=parser.parse(p.read_bytes());errors=[]
 def visit(n):
  if n.type=='ERROR' or n.is_missing:errors.append((n.type,n.start_point,n.end_point))
  for child in n.children:visit(child)
 visit(tree.root_node)
 print(p.name,errors or 'syntax parsed')
 failed |= bool(errors)
raise SystemExit(1 if failed else 0)
