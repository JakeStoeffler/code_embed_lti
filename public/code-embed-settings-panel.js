$(document).ready(function() {
  $("#save-button").on("click", saveEditor);
  $("#reset-button").on("click", resetEditor);
  
  function resetEditor() {
    var editorSettings = {};
    setupEditor(editorSettings, true);
  }
  
  function saveEditor() {
    var $saveBtn = $("#save-button");
    $("#title").after($('<span class="label" id="save-label">Saving...</span>'));
    $saveBtn.off("click");
    $saveBtn.addClass("disabled");
    
    var content = escape(ace.edit("editor").getValue());
    var editor_settings = escape(JSON.stringify(editorSettings));
    $.ajax({
      url: "/save_editor",
      type: "POST",
      dataType: "json",
      data: {
        content: content,
        editor_settings: editor_settings,
        placement_id: $('#editor-data input[name="placement-id"]').val(),
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