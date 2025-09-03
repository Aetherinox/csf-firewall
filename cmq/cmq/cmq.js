var isNav4, isNav6, isIE4;
setBrowser();

function setBrowser()
{
    if (navigator.appVersion.charAt(0) == "4")
    {
        if (navigator.appName.indexOf("Explorer") >= 0)
        {
            isIE4 = true;
        }
        else
        {
            isNav4 = true;
        }
    }
    else if (navigator.appVersion.charAt(0) > "4")
    {
        isNav6 = true;
    }
}

function getStyleBySelector( selector )
{
    if (!isNav6)
    {
        return null;
    }
    var sheetList = document.styleSheets;
    var ruleList;
    var i, j;

    /* look through stylesheets in reverse order that
       they appear in the document */
    for (i=sheetList.length-1; i >= 0; i--)
    {
        ruleList = sheetList[i].cssRules;
        for (j=0; j<ruleList.length; j++)
        {
            if (ruleList[j].type == CSSRule.STYLE_RULE &&
                ruleList[j].selectorText == selector)
            {
                return ruleList[j].style;
            }   
        }
    }
    return null;
}

function getIdProperty( id, property )
{
    if (isNav6)
    {
        var styleObject = document.getElementById( id );
        if (styleObject != null)
        {
            styleObject = styleObject.style;
            if (styleObject[property])
            {
                return styleObject[ property ];
            }
        }
        styleObject = getStyleBySelector( "#" + id );
        return (styleObject != null) ?
            styleObject[property] :
            null;
    }
    else if (isNav4)
    {
        return document[id][property];
    }
    else
    {
        return document.all[id].style[property];
    }
}

function setIdProperty( id, property, value )
{
    if (isNav6)
    {
        var styleObject = document.getElementById( id );
        if (styleObject != null)
        {
            styleObject = styleObject.style;
            styleObject[ property ] = value;
        }
        
    }
    else if (isNav4)
    {
        document[id][property] = value;
    }
    else if (isIE4)
    {
         document.all[id].style[property] = value;
    }
}

function showMenu( divNum )
{
    if (getIdProperty( "s" + divNum, "display") != "block" )
    {
        setIdProperty("s" + divNum, "display", "block");
        document.images["i" + divNum].src = "cmq/minus.png";
    }
    else
    {
        setIdProperty("s" + divNum, "display", "none");
        document.images["i" + divNum].src = "cmq/plus.png";
    }
}

function expandO( ec ,totNum )
{
    for (j=1; j<totNum + 1; j++)
    {
            if (ec == "expand")
            {
                setIdProperty("s" + j, "display", "block");
                document.images["i" + j].src = "cmq/minus.png";
            }
            else
            {
                setIdProperty("s" + j, "display", "none");
                document.images["i" + j].src = "cmq/plus.png";
            }
    }
}
