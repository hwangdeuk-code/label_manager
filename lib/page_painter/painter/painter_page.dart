// PainterPage split: delegates heavy logic to helper parts for maintainability.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:label_manager/home_page.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/models/barcode.dart';
import 'package:label_manager/page_login/login_history_page.dart';
import 'package:label_manager/drawables/barcode_drawable.dart';
import 'package:label_manager/drawables/constrained_text_drawable.dart';
import 'package:label_manager/drawables/image_box_drawable.dart';
import 'package:label_manager/drawables/table_drawable.dart';
import 'package:label_manager/flutter_painter_v2/flutter_painter.dart';
import 'package:label_manager/utils/drawable_serialization.dart';
import 'package:label_manager/models/drag_action.dart';
import 'package:label_manager/models/tool.dart' as tool;
import 'package:label_manager/helpers/quill_helpers.dart' as quill_helper;
import 'package:label_manager/widgets/canvas_area.dart';
import 'package:label_manager/widgets/inspector_panel.dart';
import 'package:label_manager/widgets/tool_panel.dart';
import 'package:label_manager/printing/raw_printer_win32.dart';
import 'package:label_manager/printing/ezpl_builder.dart' as ezpl;
import 'package:label_manager/printing/printer_profiles.dart';
import 'package:label_manager/utils/on_messages.dart'; 
import 'package:label_manager/database/db_connection_status_icon.dart';

part 'painter_page_state.dart';
part 'painter_inline_editor.dart';
part 'painter_creation.dart';
part 'painter_selection.dart';
part 'painter_helpers.dart';
part 'painter_persistence.dart';
part 'painter_build.dart';

class PainterPage extends StatefulWidget {
  const PainterPage({super.key});

  @override
  State<PainterPage> createState() => _PainterPageState();
}
