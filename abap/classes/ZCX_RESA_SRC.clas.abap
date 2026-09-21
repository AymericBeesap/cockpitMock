"! <p class="shorttext synchronized">Détermination de la source - exception</p>
"! Exception portant un message de la classe de messages ZRESA_SRC, reportable tel quel
"! dans la table REPORTED du business object.
CLASS zcx_resa_src DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " if_abap_behv_message : l'exception est reportable telle quelle dans REPORTED,
    " sans réécrire le message à la main dans chaque appelant.
    INTERFACES if_t100_message.
    INTERFACES if_abap_behv_message.

    CONSTANTS:
      BEGIN OF source_inconnue,
        msgid TYPE symsgid VALUE 'ZRESA_SRC',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_MSGV1',
        attr2 TYPE scx_attrname VALUE 'MV_MSGV2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF source_inconnue,

      BEGIN OF appel_programme_echoue,
        msgid TYPE symsgid VALUE 'ZRESA_SRC',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE 'MV_MSGV1',
        attr2 TYPE scx_attrname VALUE 'MV_MSGV2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF appel_programme_echoue,

      BEGIN OF contexte_incomplet,
        msgid TYPE symsgid VALUE 'ZRESA_SRC',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF contexte_incomplet.

    DATA mv_msgv1 TYPE string READ-ONLY.
    DATA mv_msgv2 TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous                 OPTIONAL
                iv_msgv1 TYPE string                   OPTIONAL
                iv_msgv2 TYPE string                   OPTIONAL.

ENDCLASS.


CLASS zcx_resa_src IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    mv_msgv1 = iv_msgv1.
    mv_msgv2 = iv_msgv2.
    if_abap_behv_message~m_severity = if_abap_behv_message=>severity-error.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
