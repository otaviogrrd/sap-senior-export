REPORT zhr_senior_exp_1020.

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

  gv_filename = p_serv && sy-datum && '_SENIOR_1020.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;CODSIN;SOCSIN;POSSBH'.

*---------------------------------------------------------------------*
* Seleção (PA0057 + PA0001)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p57~begda,
    p57~emfsl
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  INNER JOIN pa0057 AS p57
    ON p57~pernr = p1~pernr.

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
    lv_socsin TYPE c LENGTH 1,
    lv_possbh TYPE c LENGTH 1.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

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
* Sócio Sindicato
*---------------------------------------------------------------------*
    lv_socsin = 'N'.
*---------------------------------------------------------------------*
* Banco de horas (regra default)
*---------------------------------------------------------------------*
    lv_possbh = 'N'.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      <fs_hist>-emfsl   && ';' && " CODSIN
      lv_socsin         && ';' && " SOCSIN
      lv_possbh.                    " POSSBH

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
