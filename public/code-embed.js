$(document).ready(function() {
  var editorSettings = $.parseJSON(
      unescape($('#editor-data input[name="editor-settings"]').val()) || '{}');
  editor = setupEditor(editorSettings);
});

var defaultSettings = {
  mode: 'ace/mode/javascript',
  theme: 'ace/theme/tomorrow_night',
  fontsize: '12px',
  folding: '0',
  soft_wrap: '1',
  show_gutter: '1',
  show_print_margin: '0',
  read_only: '0'
};

function setupEditor(settings, isReset) {
  // create the ACE editor
  var editor = ace.edit("editor");
  var session = editor.getSession();
  // put content into editor if it exists
  var rawContents = '';
  if (!isReset) {
    rawContents = $('#editor-data input[name="contents"]').val();
  }
  editor.setValue(unescape(rawContents));
  editor.focus();
  // bind settings to form inputs and set defaults or user-saved settings
  bindDropdown("mode", settings, function(value) {
    session.setMode(value);
  });
  bindDropdown("theme", settings, function(value) {
    editor.setTheme(value);
  });
  bindDropdown("fontsize", settings, function(value) {
    editor.setFontSize(value);
  });
  bindCheckbox("soft_wrap", settings, function(checked) {
    session.setUseWrapMode(checked);
  });
  bindCheckbox("show_gutter", settings, function(checked) {
    editor.renderer.setShowGutter(checked);
  });
  bindCheckbox("show_print_margin", settings, function(checked) {
    editor.setShowPrintMargin(checked);
  });
  bindCheckbox("folding", settings, function(checked) {
    editor.session.setFoldStyle(checked ? "markbegin" : "manual");
    editor.setShowFoldWidgets(checked);
  });
  bindCheckbox("read_only", settings, function(checked) {
    editor.setReadOnly(checked);
  });
  
  var $editorEl = $('#editor');
  // we don't display the editor until now to prevent flickering on page load
  $editorEl.show();
  $editorEl.resizable(); // make editor resizable (via handles) using jQuery UI
  $editorEl.on("resize", function(){
    editor.resize(); // ACE needs to be told to resize
  });
  return editor;
}

// eventually this will be taken care of on server side
function getEncodedContents(element) {
  var div = document.createElement('div');
  var text = document.createTextNode(element.innerHTML);
  div.appendChild(text);
  return div.innerHTML;
}

// Huge thank you to the folks at the ACE's Kitchen Sink for much
// of this code! (http://ace.ajax.org/build/kitchen-sink.html)
function bindCheckbox(id, editorSettings, callback) {
  var el = document.getElementById(id) || {};
  var enabled = defaultSettings[id] == '1';
  if (editorSettings[id]) {
    // override default if set by user
    enabled = editorSettings[id] == '1';
  }
  el.checked = enabled;
  var onChange = function() {
    var val = !!el.checked;
    editorSettings[id] = val ? '1' : '0'; // set setting so it can be persisted
    callback(val);
  };
  el.onclick = onChange;
  onChange();
};

function bindDropdown(id, editorSettings, callback) {
  var el = document.getElementById(id) || {};
  var value = defaultSettings[id];
  if (editorSettings[id]) {
    value = editorSettings[id];
  }
  el.value = value;
  var onChange = function() {
    var val = el.value;
    editorSettings[id] = val;
    callback(val);
  };
  el.onchange = onChange;
  onChange();
};