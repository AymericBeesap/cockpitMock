@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Détermination de la source - vue racine'
@Metadata.ignorePropagatedAnnotations: true

-- Racine du business object de détermination de la source.
--
-- La lecture vient du standard (postes de DA sans source), l'écriture de ZTRESA_SRCSEL : d'où la
-- jointure externe. Un poste qui vient de recevoir sa source disparaît de la liste, puisque la DA
-- porte désormais une source — c'est le comportement attendu de la liste de travail.
-- Restent visibles les postes dont la mise à jour de la DA a échoué (SelectionStatus = 'ERR'),
-- avec le message du BAPI, pour reprise.

define root view entity ZR_ResaPurReqSource
  as select from ZI_ResaPurReqNoSource as PurReqItem

    left outer join ztresa_srcsel as Selection
      on  Selection.banfn = PurReqItem.PurchaseRequisition
      and Selection.bnfpo = PurReqItem.PurchaseRequisitionItem
{
  key PurReqItem.PurchaseRequisition,
  key PurReqItem.PurchaseRequisitionItem,

      PurReqItem.Plant,
      PurReqItem.PurchasingGroup,
      PurReqItem.PurchasingOrganization,
      PurReqItem.Material,
      PurReqItem.PurchaseRequisitionItemText,

      PurReqItem.Reservation,
      PurReqItem.OriginType,
      PurReqItem.OriginTypeText,

      PurReqItem.PurReqDate,
      PurReqItem.DeliveryDate,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PurReqItem.RequestedQuantity,
      PurReqItem.BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      PurReqItem.ItemAmount,
      PurReqItem.Currency,

      -- dernier choix enregistré, le cas échéant
      Selection.srctype                                as SelectedSourceType,
      Selection.srcid                                  as SelectedSourceId,
      Selection.srcname                                as SelectedSourceName,

      cast( case Selection.selstat when 'ERR' then 'ERR'
                                   when 'SEL' then 'SEL'
                                   else            'TODO'
            end as abap.char(4) )                      as SelectionStatus,

      cast( case Selection.selstat
                 when 'ERR' then 'Affectation refusée par la demande d''achat'
                 when 'SEL' then 'Source retenue'
                 else            'À traiter'
            end as abap.char(60) )                     as SelectionStatusText,

      -- 1 rouge (échec), 2 orange (à traiter) : aucun poste de cette liste n'est « vert »,
      -- un poste servi sort de la liste
      cast( case Selection.selstat when 'ERR' then 1
                                   else            2
            end as abap.int1 )                         as SelectionCriticality,

      Selection.updmsg                                 as SelectionMessage,

      @Semantics.amount.currencyCode: 'Currency'
      Selection.preis                                  as SelectedNetPrice,
      Selection.plifz                                  as SelectedLeadTimeDays,

      @Semantics.user.createdBy: true
      Selection.created_by                             as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Selection.created_at                             as CreatedAt,
      @Semantics.user.lastChangedBy: true
      Selection.changed_by                             as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      Selection.changed_at                             as LastChangedAt
}
