(** * Theorems about State effects *)

(* begin hide *)
From Coq Require Import
     Program
     Setoid
     Morphisms
     RelationClasses.

From Paco Require Import paco.

From ITree Require Import
     Basics.Basics
     Basics.Category
     Basics.CategoryKleisli
     Basics.MonadTheory
     Core.ITreeDefinition
     Core.KTree
     Core.KTreeFacts
     Eq.Eq
     Eq.UpToTaus
     Indexed.Sum
     Interp.Interp
     Interp.InterpFacts
     Interp.RecursionFacts
     Events.State.

Import ITree.Basics.Basics.Monads.
Import ITreeNotations.

Open Scope itree_scope.

Import Monads.
(* end hide *)

Definition _interp_state {E F S R}
           (f : E ~> stateT S (itree F)) (ot : itreeF E R _)
  : stateT S (itree F) R := fun s =>
  match ot with
  | RetF r => Ret (s, r)
  | TauF t => Tau (interp_state f t s)
  | VisF e k => Tau (f _ e s >>= (fun sx => interp_state f (k (snd sx)) (fst sx)))
  end.

Lemma unfold_interp_state {E F S R} (h : E ~> Monads.stateT S (itree F))
      (t : itree E R) s :
    eq_itree eq
      (interp_state h t s)
      (_interp_state h (observe t) s).
Proof.
  unfold interp_state, interp, aloop, ALoop_stateT0, aloop, ALoop_itree.
  rewrite unfold_aloop.
  destruct observe; cbn.
  - reflexivity.
  - rewrite bind_ret.
    reflexivity.
  - rewrite bind_map. pstep. econstructor. left.
    eapply eqit_bind; reflexivity.
Qed.

Instance eq_itree_interp_state {E F S R} (h : E ~> Monads.stateT S (itree F)) :
  Proper (eq_itree eq ==> eq ==> eq_itree eq)
         (@interp_state _ _ _ _ _ _ h R).
Proof.
  revert_until R.
  ginit. gcofix CIH. intros h x y H0 x2 y0 H1.
  rewrite !unfold_interp_state.
  unfold _interp_state.
  punfold H0; repeat red in H0.
  gstep. destruct (observe x); dependent destruction H0; try discriminate; simpobs; subst; pclearbot; constructor; eauto with paco.
  guclo eqit_clo_bind. econstructor.
  + reflexivity.
  + intros [] _ []. auto with paco.
Qed.

Lemma interp_state_ret {E F : Type -> Type} {R S : Type}
      (f : forall T, E T -> S -> itree F (S * T)%type)
      (s : S) (r : R) :
  (interp_state f (Ret r) s) ≅ (Ret (s, r)).
Proof.
  rewrite itree_eta. reflexivity.
Qed.

Lemma interp_state_vis {E F : Type -> Type} {S T U : Type}
      (e : E T) (k : T -> itree E U) (h : E ~> Monads.stateT S (itree F)) (s : S)
  : interp_state h (Vis e k) s
  ≅ Tau (h T e s >>= fun sx => interp_state h (k (snd sx)) (fst sx)).
Proof.
  rewrite unfold_interp_state; reflexivity.
Qed.

Lemma interp_state_tau {E F : Type -> Type} S {T : Type}
      (t : itree E T) (h : E ~> Monads.stateT S (itree F)) (s : S)
  : interp_state h (Tau t) s ≅ Tau (interp_state h t s).
Proof.
  rewrite unfold_interp_state; reflexivity.
Qed.

Lemma interp_state_trigger {E F : Type -> Type} {R S : Type}
      (e : E R) (f : E ~> Monads.stateT S (itree F)) (s : S)
  : (interp_state f (ITree.trigger e) s) ≅ Tau (f _ e s).
Proof.
  unfold ITree.trigger. rewrite interp_state_vis.
  pstep. econstructor. left.
  rewrite <- (bind_ret2 (f R e s)) at 2.
  eapply eqit_bind.
  - intros []; rewrite interp_state_ret; reflexivity.
  - reflexivity.
Qed.

Lemma interp_state_bind {E F : Type -> Type} {A B S : Type}
      (f : forall T, E T -> S -> itree F (S * T)%type)
      (t : itree E A) (k : A -> itree E B)
      (s : S) :
  (interp_state f (t >>= k) s)
    ≅
  (interp_state f t s >>= fun st => interp_state f (k (snd st)) (fst st)).
Proof.
  revert A t k s.
  ginit. gcofix CIH.
  intros A t k s.
  rewrite unfold_bind. (* TODO: slow *)
  rewrite (unfold_interp_state f t).
  destruct (observe t).
  - cbn. rewrite !bind_ret. simpl.
    apply reflexivity.
  - cbn. rewrite !bind_tau, interp_state_tau.
    gstep. econstructor. gbase. apply CIH.
  - cbn. rewrite interp_state_vis, bind_tau, bind_bind.
    gstep. constructor.
    guclo eqit_clo_bind. econstructor.
    + reflexivity.
    + intros u2 ? []. specialize (CIH _ (k0 (snd u2)) k (fst u2)).
      auto with paco.
Qed.

Instance eutt_interp_state {E F: Type -> Type} {S : Type}
         (h : E ~> Monads.stateT S (itree F)) R :
  Proper (eutt eq ==> eq ==> eutt eq) (@interp_state E (itree F) S _ _ _ h R).
Proof.
  repeat intro. subst. revert_until R.
  einit. ecofix CIH. intros.

  rewrite !unfold_interp_state. punfold H0. red in H0.
  induction H0; intros; subst; simpl; pclearbot.
  - eret.
  - etau.
  - etau. ebind. econstructor; [reflexivity|].
    intros; subst. ebase.
  - rewrite tau_eutt, unfold_interp_state. eauto.
  - rewrite tau_eutt, unfold_interp_state. eauto.
Qed.

Lemma eutt_interp_state_aloop {E F S I I' A A'}
      (RA : A -> A' -> Prop) (RI : I -> I' -> Prop)
      (RS : S -> S -> Prop)
      (h : E ~> Monads.stateT S (itree F))
      (t1 : I -> itree E I + A)
      (t2 : I' -> itree E I' + A'):
  (forall i i' s1 s2, RS s1 s2 -> RI i i' ->
     sum_rel (fun u1 u2 =>
                eutt (fun a b => RS (fst a) (fst b) /\ RI (snd a) (snd b))
                     (interp_state h u1 s1)
                     (interp_state h u2 s2))
             RA (t1 i) (t2 i')) ->
  (forall i i' s1 s2, RS s1 s2 -> RI i i' ->
     eutt (fun a b => RS (fst a) (fst b) /\ RA (snd a) (snd b))
          (interp_state h (ITree.aloop t1 i) s1)
          (interp_state h (ITree.aloop t2 i') s2)).
Proof.
  intro Ht.
  einit. ecofix CIH. intros.
  rewrite 2 unfold_aloop.
  destruct (Ht i i' s1 s2); cbn; auto.
  - rewrite 2 interp_state_tau, 2 interp_state_bind.
    etau. constructor.
    ebind. econstructor; eauto.
    intros [s1' i1'] [s2' i2'] [? ?]; cbn.
    auto with paco.
  - rewrite 2 interp_state_ret. eret.
Qed.

Lemma eutt_interp_state_iter {E F S A A' B B'}
      (RA : A -> A' -> Prop) (RB : B -> B' -> Prop)
      (RS : S -> S -> Prop)
      (h : E ~> Monads.stateT S (itree F))
      (t1 : A -> itree E (A + B))
      (t2 : A' -> itree E (A' + B')) :
  (forall ca ca' s1 s2, RS s1 s2 ->
                        RA ca ca' ->
     eutt (fun a b => RS (fst a) (fst b) /\ sum_rel RA RB (snd a) (snd b))
          (interp_state h (t1 ca) s1)
          (interp_state h (t2 ca') s2)) ->
  (forall a a' s1 s2, RS s1 s2 -> RA a a' ->
     eutt (fun a b => RS (fst a) (fst b) /\ RB (snd a) (snd b))
          (interp_state h (KTree.iter t1 a) s1)
          (interp_state h (KTree.iter t2 a') s2)).
Proof.
  intros.
  unfold iter, Iter_ktree.
  eapply (eutt_interp_state_aloop _ (sum_rel _ _)); auto.
  - intros ? ? ? ? ? []; constructor; auto.
  - constructor; auto.
Qed.

Lemma eutt_interp_state_loop {E F S A B C} (RS : S -> S -> Prop)
      (h : E ~> Monads.stateT S (itree F))
      (t1 t2 : C + A -> itree E (C + B)) :
  (forall ca s1 s2, RS s1 s2 ->
     eutt (fun a b => RS (fst a) (fst b) /\ snd a = snd b)
          (interp_state h (t1 ca) s1)
          (interp_state h (t2 ca) s2)) ->
  (forall a s1 s2, RS s1 s2 ->
     eutt (fun a b => RS (fst a) (fst b) /\ snd a = snd b)
          (interp_state h (loop t1 a) s1)
          (interp_state h (loop t2 a) s2)).
Proof.
  intros.
  unfold loop, bimap, Bimap_Coproduct, case_, CoprodCase_Kleisli, Function.case_sum, id_, Id_Kleisli, cat, Cat_Kleisli; cbn.
  rewrite 2 bind_ret.
  eapply (eutt_interp_state_iter eq eq); auto; intros.
  rewrite 2 interp_state_bind.
  subst.
  eapply eutt_clo_bind; eauto.
  intros.
  cbn in H2; destruct (snd u1); rewrite <- (proj2 H2).
  - rewrite bind_ret, 2 interp_state_ret.
    pstep.
    constructor.
    cbn.
    split; auto using (proj1 H2).
  - rewrite bind_ret, 2 interp_state_ret. pstep. constructor. cbn.
    split; auto using (proj1 H2).
Qed.

(* SAZ: These are probably too specialized. *)
Definition state_eq {E S X} 
  : (stateT S (itree E) X) -> (stateT S (itree E) X) -> Prop :=
  fun t1 t2 => forall s, eq_itree eq (t1 s) (t2 s).

Lemma interp_state_aloop {E F } S (f : E ~> stateT S (itree F)) {I A}
      (t  : I -> itree E I + A)
      (t' : I -> stateT S (itree F) I + A)
      (EQ_t : forall i, sum_rel (fun u u' => state_eq (State.interp_state f u) u') eq (t i) (t' i))
  : forall i, state_eq (State.interp_state f (ITree.aloop t i))
                  (aloop t' i).
Proof.
  ginit. gcofix CIH; intros i s.
  unfold aloop, ALoop_stateT0, aloop, ALoop_itree in *.
  rewrite 2 unfold_aloop. simpl.
  destruct (EQ_t i); cbn.
  - rewrite interp_state_tau, interp_state_bind.
    gstep.
    constructor.
    guclo eqit_clo_bind; econstructor; eauto.
    apply H.
    intros [s' i'] _ []. simpl.
    auto with paco.
  - rewrite interp_state_ret. gstep. constructor; auto. subst; auto.
Qed.

