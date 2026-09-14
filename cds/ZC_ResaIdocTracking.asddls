@AbapCatalog.sqlViewName: 'ZCRESAIDTRACK'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitoring détaillé des IDocs de réservation'
@Metadata.allowExtensions: true
@OData.publish: true
@Search.searchable: true

-- Vue annotée au §A7.3 du MO mais non définie dans celui-ci : ajoutée pour
-- porter la cible de navigation ResaIdoc-monitor (une ligne par IDoc).
define view ZC_ResaIdocTracking
  as select from ZI_ResaIdocMonitor
{
      @Search.defaultSearchElement: true
  key IDocNumber,

      MessageType,
      IDocType,

      @Search.defaultSearchElement: true
      SenderPartner,

      CreationDate,
      CreationTime,

      @ObjectModel.text.element: [ 'IDocStatusText' ]
      IDocStatus,
      IDocStatusText,

      IntegrationStatus,
      StatusCriticality,

      MessageClass,
      MessageNumber,
      MessageText
}
