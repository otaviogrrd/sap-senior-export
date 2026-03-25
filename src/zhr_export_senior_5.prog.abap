REPORT zhr_export_senior_5 .


*---------------------------------------------------------------------*
* Parâmetros
*---------------------------------------------------------------------*
PARAMETERS:
  p_prefix TYPE string DEFAULT 'ZHR_SENIOR_EXP_'.

*---------------------------------------------------------------------*
* Tipos
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_layout,
         layout TYPE char4,
       END OF ty_layout.

DATA: gt_layouts TYPE STANDARD TABLE OF ty_layout,
      gs_layout  TYPE ty_layout.

*---------------------------------------------------------------------*
* Layouts a criar
*---------------------------------------------------------------------*
INITIALIZATION.

  gt_layouts = VALUE #(
    ( layout = '1006' )
  ).

*---------------------------------------------------------------------*
START-OF-SELECTION.

  LOOP AT gt_layouts INTO gs_layout.

    PERFORM f_create_report USING gs_layout-layout.

  ENDLOOP.

  WRITE: / 'Reports criados com sucesso'.

*---------------------------------------------------------------------*
FORM f_create_report USING p_layout TYPE char4.

  DATA:
    lv_progname TYPE progname,
    lt_source   TYPE STANDARD TABLE OF string,
    lv_line     TYPE string.

*---------------------------------------------------------------------*
* Nome do programa
*---------------------------------------------------------------------*

  lv_progname = p_prefix && p_layout.

*---------------------------------------------------------------------*
* Código fonte do report gerado
*---------------------------------------------------------------------*

  CLEAR lt_source.

  APPEND |REPORT { lv_progname }.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |PARAMETERS: p_serv TYPE string DEFAULT '/tmp/'.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |START-OF-SELECTION.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  PERFORM f_export.| TO lt_source.
  APPEND | | TO lt_source.

*---------------------------------------------------------------------*
* FORM EXPORT
*---------------------------------------------------------------------*

  APPEND |FORM f_export.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  DATA: gv_filename TYPE string.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  gv_filename = p_serv && sy-datum && '_{ p_layout }.csv'.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  IF sy-subrc <> 0.| TO lt_source.
  APPEND |    MESSAGE 'Erro ao abrir arquivo' TYPE 'E'.| TO lt_source.
  APPEND |  ENDIF.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  WRITE: / 'Layout { p_layout } gerado:', gv_filename.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |  CLOSE DATASET gv_filename.| TO lt_source.
  APPEND | | TO lt_source.
  APPEND |ENDFORM.| TO lt_source.

*---------------------------------------------------------------------*
* Criar report
*---------------------------------------------------------------------*

  INSERT REPORT lv_progname FROM lt_source.

  IF sy-subrc = 0.
    WRITE: / 'Criado:', lv_progname.
  ELSE.
    WRITE: / 'Erro ao criar:', lv_progname.
  ENDIF.

ENDFORM.
