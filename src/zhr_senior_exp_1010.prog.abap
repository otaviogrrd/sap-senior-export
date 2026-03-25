REPORT zhr_senior_exp_1010.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1010.csv'.

  gv_header = 'TABORG;CODLOC;LOCPAI;NOMLOC;DATCRI;DATEXT'.

*---------------------------------------------------------------------*
* Sele??o OM (Locais)
*---------------------------------------------------------------------*

  SELECT
    orgeh,
    orgtx,
    begda,
    endda
  INTO TABLE @DATA(gt_org)
  FROM t527x
  WHERE endda >= @sy-datum.

*---------------------------------------------------------------------*
* Buscar relacionamento pai (HRP1001)
*---------------------------------------------------------------------*

  SELECT
    objid,     " filho
    sobid      " pai
  INTO TABLE @DATA(gt_rel)
  FROM hrp1001
  WHERE plvar = '01'
    AND otype = 'O'
    AND rsign = 'B'
    AND relat = '002'   " pertence a
    AND endda >= @sy-datum.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_datcri TYPE char10,
    lv_datext TYPE char10,
    lv_pai    TYPE string.

  LOOP AT gt_org ASSIGNING FIELD-SYMBOL(<fs_org>).

*---------------------------------------------------------------------*
* Data
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_org>-begda
      CHANGING lv_datcri.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_org>-endda
      CHANGING lv_datext.

*---------------------------------------------------------------------*
* Buscar pai
*---------------------------------------------------------------------*

    CLEAR lv_pai.

    READ TABLE gt_rel ASSIGNING FIELD-SYMBOL(<fs_rel>)
      WITH KEY objid = <fs_org>-orgeh.

    IF sy-subrc = 0.
      lv_pai = <fs_rel>-sobid.
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      '1'                    && ';' && " TABORG (fixo)
      <fs_org>-orgeh         && ';' && " CODLOC
      lv_pai                 && ';' && " LOCPAI
      <fs_org>-orgtx         && ';' && " NOMLOC
      lv_datcri              && ';' && " DATCRI
      lv_datext.                         " DATEXT

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
