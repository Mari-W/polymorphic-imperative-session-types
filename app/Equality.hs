module Equality where

import Ast (Dom (DEmpty, DProj, DTree, DVar), Kind (KDom, KLam, KSession, KShape, KState, KType), Label (LLeft, LRight), Session (SBranch, SChoice, SDual, SEnd, SRecv, SSend, SVar), Shape (SDisjoint, SEmpty, SSingle), Type)
import Result (Result, ok, raise)

domNF :: Dom -> Result Dom
domNF DEmpty = ok DEmpty
domNF (DProj l (DTree d d')) = case l of
  LLeft -> domNF d
  LRight -> domNF d'
domNF (DTree d d') = do
  d <- domNF d
  d' <- domNF d'
  ok (DTree d d')
domNF _ = raise "invalid projection to domain"

domEq :: Dom -> Dom -> Result ()
domEq d d' = do
  d <- domNF d
  d' <- domNF d'
  case (d, d') of
    (DVar i, DVar j) -> if i == j then ok () else raise "dom var mismatch"
    (DEmpty, DEmpty) -> ok ()
    (DTree d1 d1', DTree d2 d2') -> do
      domEq d1 d2 
      domEq d1' d2'
    _ -> raise "dom mismatch"

shapeEq :: Shape -> Shape -> Result ()
shapeEq SEmpty SEmpty = ok ()
shapeEq SSingle SSingle = ok ()
shapeEq (SDisjoint s1 s1') (SDisjoint s2 s2') = do
  shapeEq s1 s2 
  shapeEq s1' s2'
shapeEq _ _ = raise "shape mismatch"

kindEq :: Kind -> Kind -> Result ()
kindEq KType KType = ok ()
kindEq KSession KSession = ok ()
kindEq KState KState = ok ()
kindEq KShape KShape = ok ()
kindEq (KDom s) (KDom s') = shapeEq s s'
kindEq (KLam k1 k1') (KLam k2 k2') = do
  kindEq k1 k2
  kindEq k1' k2'
kindEq _ _ = raise "kind mismatch"

sessNF :: Session -> Session
sessNF (SDual (SDual (SVar i))) = SVar i
sessNF (SDual SEnd) = SEnd
sessNF (SDual (SSend sh st t s)) = SRecv sh st t (sessNF (SDual s))
sessNF (SDual (SRecv sh st t s)) = SSend sh st t (sessNF (SDual s))
sessNF (SDual (SChoice st1 st2)) = SBranch (sessNF (SDual st1)) (sessNF (SDual st2))
sessNF (SDual (SBranch st1 st2)) = SChoice (sessNF (SDual st1)) (sessNF (SDual st2))
sessNF st = st

sessEq :: Session -> Session -> Bool
sessEq s s' = case (sessNF s, sessNF s') of
  _ -> True