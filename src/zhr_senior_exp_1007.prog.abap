REPORT zhr_export_senior_1007.

PARAMETERS:
  p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho do servidor.' TYPE 'E'.
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

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = p_serv && sy-datum && '_SENIOR_1007.csv'.

  gv_header = 'CODBAN;NOMBAN'.

*---------------------------------------------------------------------*
* Select bancos
*---------------------------------------------------------------------*

  SELECT DISTINCT
    bankl,
    banka
  INTO TABLE @DATA(gt_bnka)
  FROM bnka
  WHERE banks = 'BR'.

*---------------------------------------------------------------------*
* Ordenar
*---------------------------------------------------------------------*

  SORT gt_bnka BY bankl.

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

  LOOP AT gt_bnka ASSIGNING FIELD-SYMBOL(<fs_bnka>).

    DATA(lv_codban) = <fs_bnka>-bankl.
    DATA(lv_nome)   = <fs_bnka>-banka.

    gv_line =
      lv_codban && ';' &&
      lv_nome.

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo 1007 gerado:', gv_filename.

ENDFORM.
