@AbapCatalog.sqlViewName: 'ZCRESAKPI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Requête cockpit - chaîne réservations'
@Analytics.query: true
@OData.publish: true
@Metadata.allowExtensions: true

define view ZC_ResaChainQuery
  as select from ZI_ResaChainCube
{
  @AnalyticsDetails.query.axis: #ROWS
  @EndUserText.label: 'Division'
  Plant,

  @AnalyticsDetails.query.axis: #ROWS
  @EndUserText.label: 'Groupe d''acheteurs'
  PurchasingGroup,

  @AnalyticsDetails.query.axis: #FREE
  @EndUserText.label: 'Origine'
  @ObjectModel.text.element: [ 'OriginTypeText' ]
  OriginType,
  OriginTypeText,

  @AnalyticsDetails.query.axis: #FREE
  @EndUserText.label: 'Étape'
  @ObjectModel.text.element: [ 'ChainStageText' ]
  ChainStage,
  ChainStageText,

  @AnalyticsDetails.query.axis: #FREE
  PurReqDate,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'Postes de DA'
  PurReqItemCount,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'Postes convertis'
  ConvertedItemCount,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'Postes en attente'
  OpenItemCount,

  @DefaultAggregation: #SUM
  @Semantics.amount.currencyCode: 'Currency'
  @EndUserText.label: 'Montant'
  ItemAmount,

  Currency,

  @AnalyticsDetails.query.formula: 'case when $projection.PurReqItemCount > 0 then $projection.ConvertedItemCount / $projection.PurReqItemCount * 100 else 0 end'
  @EndUserText.label: 'Taux de conversion'
  1 as ConversionRate
}
