REPORT ZHR_SENIOR_EXP_1023.

PARAMETERS: p_serv TYPE string DEFAULT '/tmp/'.

START-OF-SELECTION.

  PERFORM f_export.

FORM f_export.

  DATA: gv_filename TYPE string.

  gv_filename = p_serv && sy-datum && '_1023.csv'.

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo' TYPE 'E'.
  ENDIF.

  WRITE: / 'Layout 1023 gerado:', gv_filename.

  CLOSE DATASET gv_filename.

ENDFORM.
