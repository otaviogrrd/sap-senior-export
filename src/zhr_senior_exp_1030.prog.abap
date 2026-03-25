REPORT zhr_export_senior_1030.

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

  gv_filename = p_serv && sy-datum && '_SENIOR_1030.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;SEQALT;CODMOT;VALSAL;TIPSAL;PERREA'.

*---------------------------------------------------------------------*
* SELECT
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p8~begda,
    p8~bet01,
    p8~preas
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  INNER JOIN pa0008 AS p8
    ON p8~pernr = p1~pernr.

*---------------------------------------------------------------------*
* SORT
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda.

*---------------------------------------------------------------------*
* REMOVE DUPLICATES
*---------------------------------------------------------------------*

  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING
    pernr begda bet01.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

*---------------------------------------------------------------------*
* LOOP
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datalt TYPE char10,
    lv_seqalt TYPE n LENGTH 2 VALUE '00',
    lv_lastsal TYPE pa0008-bet01.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

*---------------------------------------------------------------------*
* MUDANÇA REAL (SALÁRIO)
*---------------------------------------------------------------------*

    AT NEW pernr.
      CLEAR: lv_lastsal, lv_seqalt.
    ENDAT.

    IF <fs_hist>-bet01 = lv_lastsal.
      CONTINUE.
    ENDIF.

    lv_lastsal = <fs_hist>-bet01.

*---------------------------------------------------------------------*
* Sequência
*---------------------------------------------------------------------*

    ADD 1 TO lv_seqalt.

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
* Percentual de reajuste (opcional)
*---------------------------------------------------------------------*

    DATA(lv_perrea) = ''.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      lv_seqalt         && ';' && " SEQALT
      <fs_hist>-preas   && ';' && " CODMOT
      <fs_hist>-bet01   && ';' && " VALSAL
*      <fs_hist>-lgtxt   && ';' && " TIPSAL
      lv_perrea.                   " PERREA

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado:', gv_filename.

ENDFORM.
