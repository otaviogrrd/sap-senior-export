REPORT zhr_export_senior_1014.

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

  gv_filename = p_serv && sy-datum && '_SENIOR_1014.csv'.

  gv_header =
    'ENDUZ;TIPCOL;NUMCAD;DATAFA;HORAFA;DATTER;HORTER;PRVTER;SITAFA;CAUDEM;DIAJUS;OBSAFA;CODDOE;NOMATE;ORGCLA;REGCON;ESTCON;MOTRAI'.

*---------------------------------------------------------------------*
* Seleção afastamentos
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p2001~begda,
    p2001~beguz,
    p2001~endda,
    p2001~enduz,
    p2001~awart,
    p2001~abwtg
  INTO TABLE @DATA(gt_afast)
  FROM pa0001 AS p1
  INNER JOIN pa2001 AS p2001
    ON p2001~pernr = p1~pernr.

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
    lv_tipcol TYPE c LENGTH 1,
    lv_datafa TYPE char10,
    lv_datter TYPE char10,
    lv_prvter TYPE char10,
    lv_horafa TYPE string,
    lv_horter TYPE string.

  LOOP AT gt_afast ASSIGNING FIELD-SYMBOL(<fs_afast>).

*---------------------------------------------------------------------*
* Conversões
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_afast>-persg
      CHANGING lv_tipcol.

*---------------------------------------------------------------------*
* Datas
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_afast>-begda
      CHANGING lv_datafa.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_afast>-endda
      CHANGING lv_datter.

    lv_prvter = lv_datter. " mesma regra

*---------------------------------------------------------------------*
* Hora (hh:mm)
*---------------------------------------------------------------------*

    IF <fs_afast>-beguz IS NOT INITIAL.
      lv_horafa = |{ <fs_afast>-beguz+0(2) }:{ <fs_afast>-beguz+2(2) }|.
    ENDIF.

    IF <fs_afast>-enduz IS NOT INITIAL.
      lv_horter = |{ <fs_afast>-enduz+0(2) }:{ <fs_afast>-enduz+2(2) }|.
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_afast>-bukrs     && ';' && " ENDUZ
      lv_tipcol            && ';' && " TIPCOL
      <fs_afast>-pernr     && ';' && " NUMCAD
      lv_datafa            && ';' && " DATAFA
      lv_horafa            && ';' && " HORAFA
      lv_datter            && ';' && " DATTER
      lv_horter            && ';' && " HORTER
      lv_prvter            && ';' && " PRVTER
      <fs_afast>-awart     && ';' && " SITAFA
      ''                   && ';' && " CAUDEM
      <fs_afast>-abwtg     && ';' && " DIAJUS
      ''                   && ';' && " OBSAFA
      ''                   && ';' && " CODDOE
      ''                   && ';' && " NOMATE
      ''                   && ';' && " ORGCLA
      ''                   && ';' && " REGCON
      ''                   && ';' && " ESTCON
      ''.                              " MOTRAI

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
