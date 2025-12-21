<iframe
    name="myiframe"
    id="myiframe"
    src="/nodeworx/configservercsf/"
    style="width:100%; overflow:hidden;"
    frameborder="0"
    scrolling="no"
    onload="resizeIframe( this );">
</iframe>


{literal}
    <script>
        function resizeIframe( obj )
        {
            var extraPadding = 50;

            obj.style.height =
                ( obj.contentWindow.document.documentElement.scrollHeight
                + extraPadding ) + 'px';

            obj.style.overflow = 'hidden';
            window.scrollTo( 0, 0 );
        }

        window.parent.parent.scrollTo( 0, 0 );
    </script>
{/literal}
