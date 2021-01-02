$(function() {
    $('[id^=user-dialog-]').dialog({
        title: "",
        width: 1080,
        autoOpen: false,
        modal: true,
        buttons: {
            "Close": function() {
                $(this).dialog("close");
            }
        }
    });
})
