"! <p class="shorttext synchronized">Fournisseur des sources d'approvisionnement</p>
"! Point d'entrée unique vers la règle de détermination, qui reste dans S/4 (programme,
"! module fonction ou classe existants — ⟨PROGRAMME_SOURCES⟩).
"!
"! Cette interface existe pour trois raisons :
"! <ul>
"! <li>le business object et la classe de requête ne connaissent pas le programme appelé ;</li>
"! <li>les tests unitaires injectent un double sans appeler S/4 ;</li>
"! <li>si la détermination bascule un jour vers un webservice, seule l'implémentation change.</li>
"! </ul>
INTERFACE zif_resa_src_provider
  PUBLIC.

  TYPES:
    "! Contexte du besoin pour lequel on cherche des sources
    BEGIN OF ty_request,
      plant         TYPE werks_d,
      material      TYPE matnr,
      quantity      TYPE menge_d,
      base_unit     TYPE meins,
      delivery_date TYPE eindt,
    END OF ty_request.

  TYPES:
    "! Une source proposée. Les champs d'affectation (supplier, info_record, purchasing_org,
    "! supplying_plant) sont repris tels quels dans la demande d'achat : c'est ⟨PROGRAMME_SOURCES⟩
    "! qui décide de ce qui caractérise une source, pas cette application.
    BEGIN OF ty_source,
      source_type      TYPE zresa_srctype,
      source_id        TYPE zresa_srcid,
      source_name      TYPE zresa_srcname,
      supplier         TYPE lifnr,
      info_record      TYPE infnr,
      purchasing_org   TYPE ekorg,
      supplying_plant  TYPE reswk,
      availability     TYPE c LENGTH 1,
      available_qty    TYPE menge_d,
      base_unit        TYPE meins,
      net_price        TYPE preis,
      currency         TYPE waers,
      lead_time_days   TYPE plifz,
      source_rank      TYPE i,
    END OF ty_source,
    tt_source TYPE STANDARD TABLE OF ty_source WITH EMPTY KEY.

  "! Sources disponibles pour un besoin.
  "! Une table vide est une réponse valide (aucune source) ; un appel en échec lève une exception.
  METHODS get_sources
    IMPORTING is_request        TYPE ty_request
    RETURNING VALUE(rt_sources) TYPE tt_source
    RAISING   zcx_resa_src.

  "! Relecture d'une source retenue, pour ne jamais enregistrer un choix qui n'existe plus
  "! entre l'ouverture de la pop-up et la validation de l'action.
  METHODS get_source
    IMPORTING is_request       TYPE ty_request
              iv_source_type   TYPE zresa_srctype
              iv_source_id     TYPE zresa_srcid
    RETURNING VALUE(rs_source) TYPE ty_source
    RAISING   zcx_resa_src.

ENDINTERFACE.
