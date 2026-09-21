@EndUserText.label : 'Source d''approvisionnement retenue par poste de DA'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED

-- Trace du choix de source. Une ligne par poste de demande d'achat, créée ou mise à jour
-- par l'action SelectSource en phase de sauvegarde du business object (MODIFY, jamais d'UPDATE seul :
-- la ligne n'existe pas tant que l'utilisateur n'a rien retenu).
--
-- La source elle-même n'est pas stockée en base : elle est calculée à chaque appel par
-- ⟨PROGRAMME_SOURCES⟩ (cf. ZCL_RESA_SRC_PROVIDER). Cette table ne conserve que le choix retenu,
-- ses caractéristiques au moment du choix (prix, délai) et le résultat de la mise à jour de la DA.

define table ztresa_srcsel {

  key mandt      : mandt not null;
  key banfn      : banfn not null;
  key bnfpo      : bnfpo not null;

  -- source retenue
  srctype        : zresa_srctype;                   -- EDI / WHSE / STOR
  srcid          : zresa_srcid;                     -- fournisseur, entrepôt ou division voisine
  srcname        : zresa_srcname;

  -- champs d'affectation portés dans la demande d'achat (cf. ZCL_RESA_SRC_PRUPDATE)
  lifnr          : lifnr;                           -- fournisseur fixe (source EDI)
  infnr          : infnr;                           -- fiche info achat
  ekorg          : ekorg;
  reswk          : reswk;                           -- division livreuse (source WHSE / STOR)

  -- caractéristiques de la source au moment du choix, pour audit et comparaison a posteriori
  @Semantics.amount.currencyCode : 'waers'
  preis          : preis;
  waers          : waers;
  plifz          : plifz;                           -- délai prévisionnel en jours

  -- état du choix : SEL (retenue) / ERR (mise à jour de la DA refusée)
  selstat        : zresa_selstat;
  updmsg         : zresa_updmsg;                    -- message du BAPI en cas d'échec

  created_by     : syuname;
  created_at     : timestampl;
  changed_by     : syuname;
  changed_at     : timestampl;

}
