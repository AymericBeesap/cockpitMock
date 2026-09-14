@AbapCatalog.sqlViewName: 'ZCRESAIDKPI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Requête cockpit - intégration des réservations'
@Analytics.query: true
@OData.publish: true
@Metadata.allowExtensions: true

define view ZC_ResaIdocQuery
  as select from ZI_ResaIdocMonitor
{
  @AnalyticsDetails.query.axis: #ROWS
  @EndUserText.label: 'Magasin émetteur'
  SenderPartner,

  @AnalyticsDetails.query.axis: #FREE
  @EndUserText.label: 'Statut d''intégration'
  IntegrationStatus,

  @AnalyticsDetails.query.axis: #FREE
  CreationDate,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'IDocs reçus'
  IDocCount,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'IDocs en erreur'
  IDocErrorCount,

  @AnalyticsDetails.query.formula: 'case when $projection.IDocCount > 0 then ( $projection.IDocCount - $projection.IDocErrorCount ) / $projection.IDocCount * 100 else 0 end'
  @EndUserText.label: 'Taux d''intégration'
  1 as IntegrationRate
}
