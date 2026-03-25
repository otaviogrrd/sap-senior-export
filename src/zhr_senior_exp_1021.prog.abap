REPORT ZHR_SENIOR_EXP_1021.

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

  gv_filename = p_serv && sy-datum && '_SENIOR_1021.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;EMPATU;CADATU;CODFIL;TIPADM;FICREG;ADMESO'.

*---------------------------------------------------------------------*
* Seleção (PA0001 + PA0000)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p1~begda,
    p1~werks,
    p1~btrtl,
    p0~massn,
    p0~massg
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  LEFT JOIN pa0000 AS p0
    ON p0~pernr = p1~pernr
   AND p0~begda = p1~begda.

*---------------------------------------------------------------------*
* Ordenação
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda.

*---------------------------------------------------------------------*
* Arquivo
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
    lv_tipcol TYPE c LENGTH 1,
    lv_datalt TYPE char10,
    lv_tipadm TYPE c LENGTH 2,
    lv_admeso TYPE c LENGTH 1,
    lv_ficreg TYPE string.

  SORT gt_hist BY pernr begda werks btrtl.

  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda werks btrtl.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).
    DATA: lv_last_werks TYPE werks_d,
          lv_last_btrtl TYPE btrtl.

    AT NEW pernr.
      CLEAR: lv_last_werks, lv_last_btrtl.
    ENDAT.

    IF <fs_hist>-werks = lv_last_werks
     AND <fs_hist>-btrtl = lv_last_btrtl.
      CONTINUE.
    ENDIF.

    lv_last_werks = <fs_hist>-werks.
    lv_last_btrtl = <fs_hist>-btrtl.
*---------------------------------------------------------------------*
* Conversões
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-begda
      CHANGING lv_datalt.

*---------------------------------------------------------------------*
* Tipo admissão (MASSN/MASSG)
*---------------------------------------------------------------------*

    " TIPADM (2 posições)
    PERFORM f_conv_tipadm IN PROGRAM zhr_export_senior
      USING <fs_hist>-massn <fs_hist>-massg
      CHANGING lv_tipadm.

    " ADMESO (1 posição)
    PERFORM f_conv_tipadm IN PROGRAM zhr_export_senior
      USING <fs_hist>-massn <fs_hist>-massg
      CHANGING lv_tipadm.

*---------------------------------------------------------------------*
* FICREG (fallback)
*---------------------------------------------------------------------*
    lv_ficreg = <fs_hist>-pernr.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      <fs_hist>-werks   && ';' && " EMPATU
      <fs_hist>-btrtl   && ';' && " CADATU
      <fs_hist>-btrtl   && ';' && " CODFIL
      lv_tipadm         && ';' && " TIPADM
      lv_ficreg         && ';' && " FICREG
      lv_admeso.                    " ADMESO

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
