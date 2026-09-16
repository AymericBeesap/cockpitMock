@AbapCatalog.sqlViewName: 'ZCRESAPCORD'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Commandes petite caisse'
@Metadata.allowExtensions: true
@OData.publish: true
@Search.searchable: true

-- Document de commande petite caisse (type ZPC), rattaché à la réservation et au poste
-- de demande d'achat d'origine : c'est ce rattachement qui rend l'achat local traçable
-- dans le suivi de la chaîne, au même titre qu'une commande d'achat.
--
-- ⚠️ À BRANCHER : ztresa_pcorder est la table de persistance à créer (ou l'objet de gestion
--    retenu si le projet préfère s'appuyer sur un document standard).
define view ZC_ResaPettyCashOrder
  as select from ztresa_pcorder as PettyCash
{
      @Search.defaultSearchElement: true
  key cast( PettyCash.pcnum as abap.char(10) )         as PettyCashOrder,

      @Search.defaultSearchElement: true
      cast( PettyCash.resnum as abap.char(20) )        as Reservation,
      cast( PettyCash.banfn as abap.char(10) )         as PurchaseRequisition,
      cast( PettyCash.bnfpo as abap.char(5) )          as PurchaseRequisitionItem,

      cast( PettyCash.werks as abap.char(4) )          as Plant,
      cast( PettyCash.matnr as abap.char(40) )         as Material,
      cast( PettyCash.txz01 as abap.char(40) )         as ItemText,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PettyCash.menge                                  as Quantity,
      cast( PettyCash.meins as abap.char(3) )          as BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      PettyCash.netwr                                  as Amount,
      cast( PettyCash.waers as abap.char(5) )          as Currency,

      cast( PettyCash.lifname as abap.char(80) )       as LocalSupplierName,

      PettyCash.erdat                                  as CreationDate,
      cast( PettyCash.ernam as abap.char(12) )         as CreatedByUser,

      @ObjectModel.text.element: [ 'PettyCashStatusText' ]
      cast( PettyCash.status as abap.char(2) )         as PettyCashStatus,
      cast( case PettyCash.status
              when 'CR' then 'Créée'
              when 'JU' then 'Justificatif reçu'
              when 'CL' then 'Soldée'
              else           'Statut inconnu'
            end as abap.char(40) )                     as PettyCashStatusText
}
