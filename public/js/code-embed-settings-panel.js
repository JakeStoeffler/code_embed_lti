$(document).ready(function() {
  $("#save-button").on("click", saveEditor);
  $("#reset-button").on("click", resetEditor);
  
  window.setTimeout(function(){
      $.CodeEmbed.editor.selection.selectAll();
  }, 1000);
  
  function resetEditor() {
    $.CodeEmbed.editorSettings = {};
    setupEditor(true);
  }
  
  function saveEditor() {
    var $saveBtn = $("#save-button");
    $("#title").after($('<span class="label" id="save-label">Saving...</span>'));
    $saveBtn.off("click");
    $saveBtn.addClass("disabled");
    
    var content = escape(ace.edit("editor").getValue());
    var editorSettings = escape(JSON.stringify($.CodeEmbed.editorSettings));
    $.ajax({
      url: "/save_editor",
      type: "POST",
      dataType: "json",
      data: {
        content: content,
        editor_settings: editorSettings,
        placement_id: $('#editor-data input[name="placement-id"]').val(),
        for_outcome: $('#editor-data input[name="for-outcome"]').val(),
        return_url: $('#editor-data input[name="return-url"]').val()
      },
      success: function(data) {
        if (data.success) {
          $('#save-label').addClass('label-success').text("Saved!");
          if (data.redirect_url) {
              // Redirect to show the editor that was just saved
              window.location.href = data.redirect_url;
          }
        }
        else {
          alert("There was a problem saving the editor.");
        }
      },
      error: function(jqXHR, textStatus, errorThrown) {
        alert("There was a problem saving the editor: " + errorThrown);
      }
    });
  }
});