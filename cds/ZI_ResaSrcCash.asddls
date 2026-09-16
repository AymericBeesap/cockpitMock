@AbapCatalog.sqlViewName: 'ZIRESASRCCSH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source d''appro - commande petite caisse'

-- Socle commun de détermination de la source d'approvisionnement (4/4).
-- Restitue l'option « commande petite caisse », rattachée à la réservation d'origine.
-- C'est l'option de dernier recours lorsqu'aucun approvisionnement fournisseur n'est disponible.
--
-- ⚠️ À BRANCHER : le plafond d'éligibilité doit venir du paramétrage (montant maximum
--    autorisé par centre et par dépense), pas de la constante ci-dessous.
define view ZI_ResaSrcCash
  as select from ZI_ResaChainCube as Item
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,

      cast( 'CASH' as abap.char(4) )                   as SourceType,
      cast( 'Commande petite caisse' as abap.char(40) ) as SourceTypeText,

      cast( 'PETITECAISSE' as abap.char(10) )          as SourceId,
      cast( 'Achat local - petite caisse' as abap.char(80) ) as SourceName,

      cast( 'A' as abap.char(1) )                      as Availability,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Item.RequestedQuantity                           as AvailableQuantity,
      Item.BaseUnit,

      cast( 0 as abap.int4 )                           as LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      Item.ItemAmount                                  as NetPrice,
      Item.Currency
}
where Item.PurchaseOrder = ''
  and Item.ItemAmount    <= 200   -- TODO : plafond de petite caisse à paramétrer
