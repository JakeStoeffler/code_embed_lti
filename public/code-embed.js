function setupEditor() {
  // unescape the editor's contents before creating ACE
  var $editorEl = $('#editor');
  $editorEl.text(unescape($editorEl.text()));
  // create the ACE editor
  var editor = ace.edit("editor");
  var editorSess = editor.getSession();
  // change settings
  editor.setTheme("ace/theme/monokai");
  editorSess.setMode("ace/mode/javascript");
  editorSess.setUseWrapMode(true);
  
  // we don't display the editor until now to prevent flickering on page load
  $editorEl.show();
  $editorEl.resizable(); // make editor resizable with handles using jQuery UI
  return editor;
}

// eventually this will be taken care of on server side
function getEncodedContents(element) {
  var div = document.createElement('div');
  var text = document.createTextNode(element.innerHTML);
  div.appendChild(text);
  return div.innerHTML;
}