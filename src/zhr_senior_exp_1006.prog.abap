REPORT zhr_export_senior_1006.

PARAMETERS:
  p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = p_serv && sy-datum && '_SENIOR_1006.csv'.

  gv_header = 'CODMOT;NOMMOT;TIPMOT;MTVALT;TPOMVT'.

*---------------------------------------------------------------------*
* Seleção de motivos (T530)
*---------------------------------------------------------------------*

  SELECT
    massg,   " Código motivo
    mgtxt,   " Descrição
    massn    " Tipo movimentação
  INTO TABLE @DATA(gt_motivos)
  FROM t530t.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo.' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

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

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
