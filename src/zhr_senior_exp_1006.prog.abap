REPORT zhr_senior_exp_1006.

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

  gv_filename = sy-datum && '_SENIOR_1006.csv'.

  gv_header = 'CODMOT;NOMMOT;TIPMOT;MTVALT;TPOMVT'.

*---------------------------------------------------------------------*
* Selecao de motivos (T530)
*---------------------------------------------------------------------*

  SELECT
    massg,   " Codigo motivo
    mgtxt,   " Descricao
    massn    " Tipo movimentacao
  INTO TABLE @DATA(gt_motivos)
  FROM t530t
  WHERE SPRSL = 'P'.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipmot TYPE c LENGTH 1,
    lv_mtvalt TYPE c LENGTH 1,
    lv_tpomvt TYPE c LENGTH 1.

  LOOP AT gt_motivos ASSIGNING FIELD-SYMBOL(<fs_mot>).

*---------------------------------------------------------------------*
* TIPMOT - Lista LTipMot
*---------------------------------------------------------------------*

    PERFORM f_conv_tipmot IN PROGRAM zhr_export_senior
      USING <fs_mot>-massg
      CHANGING lv_tipmot.

    IF lv_tipmot IS INITIAL.
      lv_tipmot = 'E'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* MTVALT - Lista LMtvAlt
*---------------------------------------------------------------------*

    PERFORM f_conv_mtvalt IN PROGRAM zhr_export_senior
      USING <fs_mot>-massg
      CHANGING lv_mtvalt.

    IF lv_mtvalt IS INITIAL.
      lv_mtvalt = '0'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* TPOMVT - Lista LTpoMvt
*---------------------------------------------------------------------*

    PERFORM f_conv_tpomvt IN PROGRAM zhr_export_senior
      USING <fs_mot>-massn
      CHANGING lv_tpomvt.

    IF lv_tpomvt IS INITIAL.
      lv_tpomvt = '0'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_mot>-massg     && ';' && " CODMOT
      <fs_mot>-mgtxt     && ';' && " NOMMOT
      lv_tipmot          && ';' && " TIPMOT
      lv_mtvalt          && ';' && " MTVALT
      lv_tpomvt.                   " TPOMVT

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
