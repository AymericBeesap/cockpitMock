@AbapCatalog.sqlViewName: 'ZCRESATRACK'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Suivi détaillé de la chaîne'
@Metadata.allowExtensions: true
@OData.publish: true
@Search.searchable: true

define view ZC_ResaChainTracking
  as select from ZI_ResaChainCube
{
      @Search.defaultSearchElement: true
  key PurchaseRequisition,
  key PurchaseRequisitionItem,

      @Search.defaultSearchElement: true
      Reservation,

      @Search.defaultSearchElement: true
      SalesOrder,
      SalesOrderItem,
      SalesOrderItemText,

      PurchaseOrder,
      PurchaseOrderItem,
      PurchaseOrderItemText,

      @ObjectModel.text.element: [ 'OriginTypeText' ]
      OriginType,
      OriginTypeText,

      @ObjectModel.text.element: [ 'ChainStageText' ]
      ChainStage,
      ChainStageText,

      ChainCriticality,

      Plant,
      PurchasingGroup,
      Material,
      PurchaseRequisitionItemText,
      PurReqDate,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      RequestedQuantity,
      BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      ItemAmount,
      Currency
}
