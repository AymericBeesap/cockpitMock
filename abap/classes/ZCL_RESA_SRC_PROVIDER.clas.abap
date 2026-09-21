"! <p class="shorttext synchronized">Appel du programme de détermination des sources</p>
"! Implémentation de ZIF_RESA_SRC_PROVIDER contre ⟨PROGRAMME_SOURCES⟩.
"!
"! ⚠️ À vérifier (relevé R2) : nom et signature réels du module fonction (ou de la classe) de
"! détermination des sources, et signification des codes de type de source et de disponibilité.
"! Tant que les ⟨…⟩ ne sont pas remplacés, cette classe ne s'active pas : c'est volontaire.
CLASS zcl_resa_src_provider DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES zif_resa_src_provider.

    "! Instance courante. Un double injecté par set_instance( ) a la priorité : c'est le seul
    "! moyen de tester la chaîne complète sans appeler S/4.
    CLASS-METHODS get_instance
      RETURNING VALUE(ro_provider) TYPE REF TO zif_resa_src_provider.

    "! Réservé aux tests unitaires. Passer une référence vide rétablit l'implémentation réelle.
    CLASS-METHODS set_instance
      IMPORTING io_provider TYPE REF TO zif_resa_src_provider OPTIONAL.

  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zif_resa_src_provider.

    "! Traduction de la structure rendue par ⟨PROGRAMME_SOURCES⟩ vers le type de l'interface.
    METHODS map_source
      IMPORTING is_raw           TYPE any
      RETURNING VALUE(rs_source) TYPE zif_resa_src_provider=>ty_source.

ENDCLASS.


CLASS zcl_resa_src_provider IMPLEMENTATION.

  METHOD get_instance.
    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_resa_src_provider( ).
    ENDIF.
    ro_provider = go_instance.
  ENDMETHOD.


  METHOD set_instance.
    go_instance = io_provider.
  ENDMETHOD.


  METHOD zif_resa_src_provider~get_sources.

    " Le contexte est obligatoire : hors division / article, la question n'a pas de sens.
    IF is_request-plant IS INITIAL OR is_request-material IS INITIAL.
      RAISE EXCEPTION TYPE zcx_resa_src
        EXPORTING textid = zcx_resa_src=>contexte_incomplet.
    ENDIF.

    DATA lt_raw TYPE STANDARD TABLE OF ⟨STRUCTURE_SOURCES⟩.
    DATA lv_subrc TYPE sy-subrc.

    CALL FUNCTION '⟨PROGRAMME_SOURCES⟩'
      EXPORTING
        i_werks    = is_request-plant
        i_matnr    = is_request-material
        i_menge    = is_request-quantity
        i_meins    = is_request-base_unit
        i_eindt    = is_request-delivery_date
      IMPORTING
        e_subrc    = lv_subrc
      TABLES
        t_sources  = lt_raw
      EXCEPTIONS
        OTHERS     = 1.

    " Un appel en échec n'est jamais silencieux : renvoyer une liste vide ferait croire à
    " l'acheteur qu'aucune source n'existe, ce qui n'est pas la même information.
    IF sy-subrc <> 0 OR lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_resa_src
        EXPORTING textid   = zcx_resa_src=>appel_programme_echoue
                  iv_msgv1 = CONV #( is_request-plant )
                  iv_msgv2 = CONV #( is_request-material ).
    ENDIF.

    LOOP AT lt_raw INTO DATA(ls_raw).
      APPEND map_source( ls_raw ) TO rt_sources.
    ENDLOOP.

    SORT rt_sources BY source_rank ASCENDING
                       net_price   ASCENDING.

  ENDMETHOD.


  METHOD zif_resa_src_provider~get_source.

    DATA(lt_sources) = zif_resa_src_provider~get_sources( is_request ).

    rs_source = VALUE #( lt_sources[ source_type = iv_source_type
                                     source_id   = iv_source_id ] OPTIONAL ).

    " La pop-up a pu être ouverte il y a plusieurs minutes : une source disparue entre-temps
    " ne doit pas être enregistrée.
    IF rs_source IS INITIAL.
      RAISE EXCEPTION TYPE zcx_resa_src
        EXPORTING textid   = zcx_resa_src=>source_inconnue
                  iv_msgv1 = CONV #( iv_source_type )
                  iv_msgv2 = CONV #( iv_source_id ).
    ENDIF.

  ENDMETHOD.


  METHOD map_source.

    " ⚠️ Relevé R2 : adapter les noms de champs à la structure réelle de ⟨PROGRAMME_SOURCES⟩,
    " en particulier les codes de type de source (attendus : EDI / WHSE / STOR) et de
    " disponibilité (attendus : A disponible, B partielle, C indisponible).
    rs_source = CORRESPONDING #( is_raw ).

  ENDMETHOD.

ENDCLASS.
