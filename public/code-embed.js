function setupEditor() {
	var editorEl = document.getElementById("editor");
	editorEl.style.display = "block";
	// encode the editor's contents in case it contains any HTML code
	//encodeContents(editorEl);
	var editor = ace.edit("editor");
	var editorSess = editor.getSession();
	editor.setTheme("ace/theme/monokai");
	editorSess.setMode("ace/mode/javascript");
	editorSess.setUseWrapMode(true);
    return editor;
}

// eventually this will be taken care of on server side
function encodeContents(element) {
   var div = document.createElement('div');
   var text = document.createTextNode(element.innerHTML);
   div.appendChild(text);
   element.innerHTML = div.innerHTML;
}