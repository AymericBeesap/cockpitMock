@AbapCatalog.sqlViewName: 'ZIRESASRCAVL'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sources d''approvisionnement disponibles par poste'

-- Socle commun : union des quatre familles de sources. Une ligne par poste de demande
-- d'achat ET par source candidate. C'est le point de concentration de la complexité :
-- toute évolution des règles d'approvisionnement se fait ici, sans impact sur les écrans.
--
-- Aucune règle de priorité n'est appliquée : l'écran restitue les options côte à côte et
-- l'utilisateur choisit. Si une priorité devait être introduite, elle se matérialiserait
-- par un champ de rang calculé dans cette vue.
define view ZI_ResaSourceAvail
  as select from ZI_ResaSrcEdi
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
  key SourceType,
  key SourceId,
      SourceTypeText,
      SourceName,
      Availability,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      AvailableQuantity,
      BaseUnit,
      LeadTimeDays,
      @Semantics.amount.currencyCode: 'Currency'
      NetPrice,
      Currency
}

union all

select from ZI_ResaSrcWhse
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
  key SourceType,
  key SourceId,
      SourceTypeText,
      SourceName,
      Availability,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      AvailableQuantity,
      BaseUnit,
      LeadTimeDays,
      @Semantics.amount.currencyCode: 'Currency'
      NetPrice,
      Currency
}

union all

select from ZI_ResaSrcStore
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
  key SourceType,
  key SourceId,
      SourceTypeText,
      SourceName,
      Availability,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      AvailableQuantity,
      BaseUnit,
      LeadTimeDays,
      @Semantics.amount.currencyCode: 'Currency'
      NetPrice,
      Currency
}

union all

select from ZI_ResaSrcCash
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
  key SourceType,
  key SourceId,
      SourceTypeText,
      SourceName,
      Availability,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      AvailableQuantity,
      BaseUnit,
      LeadTimeDays,
      @Semantics.amount.currencyCode: 'Currency'
      NetPrice,
      Currency
}
