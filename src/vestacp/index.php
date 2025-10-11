<link rel="stylesheet" href="<?php $_SERVER['DOCUMENT_ROOT'] ?>/css/styles.min.css">
<style>
.l-header {
    background-color: #222e44 !important;
}
</style>

<?php
/*
    VestaCP migrated to React in their v1.0 update.
    All pages are pre-compiled into .js / .css bundle and then pushed
    to the VestaCP repo.
*/

error_reporting(NULL);

$TAB = 'CSF';

include($_SERVER['DOCUMENT_ROOT']."/inc/main.php");
include($_SERVER['DOCUMENT_ROOT'].'/templates/admin/panel.html');
top_panel(empty($_SESSION['look']) ? $_SESSION['user'] : $_SESSION['look'], $TAB);

if ($_SESSION['user'] != 'admin')
{
    header("Location: /list/user");
    exit;
}

include($_SERVER['DOCUMENT_ROOT'].'/templates/header.html');
top_panel(empty($_SESSION['look']) ? $_SESSION['user'] : $_SESSION['look'], $TAB);

?>
    <div class="l-separator"></div>
    <!-- /.l-separator -->
	<div class="l-center units">
        <iframe scrolling='auto' name='myiframe' id='myiframe' src='frame.php' frameborder='0' width='100%' onload='resizeIframe(this);'></iframe>

        <script>
            function resizeIframe( obj ) 
            {
                obj.style.height = obj.contentWindow.document.body.scrollHeight + 'px';
                window.scrollTo(0,0);
                window.parent.scrollTo(0,0);
                window.parent.parent.scrollTo(0,0);
            }
        </script>
    </div>

<?php
$_SESSION['back'] = $_SERVER['REQUEST_URI'];

include($_SERVER['DOCUMENT_ROOT'].'/templates/scripts.html');
include($_SERVER['DOCUMENT_ROOT'].'/templates/footer.html');
