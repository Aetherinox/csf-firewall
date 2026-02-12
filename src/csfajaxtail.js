/*
    @app                ConfigServer Security & Firewall (CSF)
                        Login Failure Daemon (LFD)
    @website            https://configserver.dev
    @docs               https://docs.configserver.dev
    @download           https://download.configserver.dev
    @repo               https://github.com/Aetherinox/csf-firewall
    @copyright          Copyright (C) 2025-2026 Aetherinox
                        Copyright (C) 2006-2025 Jonathan Michaelson
                        Copyright (C) 2006-2025 Way to the Web Ltd.
    @license            GPLv3
    @updated            02.12.2026
    
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or (at
    your option) any later version.
    
    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, see <https://www.gnu.org/licenses>.
*/

/*
	Declarations

	@note				Existing vars are replaced dynamically by Perl injection via DisplayUI.pm;
						must remain var for global exposure and mutation safety.

	@todo				Modify how this works later when there's more free time
*/

var csfScript = '';
var csfDuration = typeof csfDuration !== 'undefined' ? csfDuration : 6;
var csfFromBot = 120;
var csfFromRight = 10;
let csfCounter;
let csfCount = 1;
var csfStartPaused = (typeof csfStartPaused !== 'undefined') ? csfStartPaused : 0;
let csfPause = csfStartPaused;
let csfTimerSet = 0;
let csfHeight = 0;
let csfWidth = 0;
const csfAjaxHttp = csfCreateReqObject( );

/*
    Initial state of pause button
*/

const pauseBtn = document.getElementById( 'csfPauseId' );
if ( pauseBtn )
{
    pauseBtn.textContent = csfPause ? 'Continue' : 'Pause';
}

/*
    Creates and returns a compatible XMLHttpRequest object
*/

function csfCreateReqObject( )
{
    let csfAjaxReq;

    if ( window.XMLHttpRequest )
    {
        csfAjaxReq = new XMLHttpRequest( );
    }
    else if ( window.ActiveXObject )
    {
        csfAjaxReq = new ActiveXObject( 'Microsoft.XMLHTTP' );
    }
    else
    {
        alert( 'There was a problem creating the XMLHttpRequest object in your browser' );
        csfAjaxReq = '';
    }

    return csfAjaxReq;
}

/*
    Sends an asynchronous GET request to the specified URL
*/

function csfSendReq( url )
{
    const now = new Date( );

    csfAjaxHttp.open( 'get', url + '&nocache=' + now.getTime( ) );
    csfAjaxHttp.onreadystatechange = csfHandleResp;
    csfAjaxHttp.send( );

    document.getElementById( 'csfRefreshing' ).style.display = 'inline';
}

/*
    Handles and processes the ajax response from the server
*/

function csfHandleResp( )
{
    if ( csfAjaxHttp.readyState == 4 && csfAjaxHttp.status == 200 )
    {
        if ( csfAjaxHttp.responseText )
        {

            /*
                I despise using !important, but we must do this to force
                the minimum height and resize for Webmin.
            */

            const csfObj = document.getElementById( 'csfAjax' );
            csfObj.innerHTML = csfAjaxHttp.responseText;
            csfObj.style.setProperty('min-height', '500px');
            csfObj.style.setProperty('resize', 'vertical', 'important');
            csfObj.style.setProperty('overflow', 'auto', 'important');

            waitForElement( 'csfAjax', function( )
            {
                csfObj.scrollTop = csfObj.scrollHeight;
            });

            document.getElementById( 'csfRefreshing' ).style.display = 'none';

            if ( csfTimerSet )
                csfCounter = setInterval( csfTimerInitialize, 1000 );
        }
    }
}

/*
    Waits for an element to exist in the DOM, then executes a callback
*/

function waitForElement( elementId, callBack )
{
    window.setTimeout( function( )
    {
        const element = document.getElementById( elementId );

        if ( element )
            callBack( elementId, element );
        else
            waitForElement( elementId, callBack );

    }, 500 );
}

/*
    Handles log grep requests using user input and selected options
*/

function csfGrep( )
{
    csfTimerSet = 0;

    const csfLogObj = document.getElementById( 'csfLogNum' );
    let csfLogNum;

    if ( csfLogObj )
        csfLogNum = '&lognum=' + csfLogObj.options[ csfLogObj.selectedIndex ].value;
    else
        csfLogNum = '';

    if ( document.getElementById( 'CSFgrep_i' ).checked )
        csfLogNum += '&grepi=1';

    if ( document.getElementById( 'CSFgrep_E' ).checked )
        csfLogNum += '&grepE=1';

    if ( document.getElementById( 'CSFgrep_Z' ).checked )
        csfLogNum += '&grepZ=1';

    const csfUrl = csfScript + '&grep=' + document.getElementById( 'csfGrep' ).value + csfLogNum;
    csfSendReq( csfUrl );
}

/*
    Timer › Initialize

    Automatically refreshes on-screen logs at regular intervals
*/

function csfTimerInitialize( ) 
{
    csfTimerSet = 1;

    const timerEl = document.getElementById( 'csfTimer' );
    if ( !timerEl ) return;

    /*
        Ensure interval is only set once
    */

    if ( !csfCounter )
    {
        csfCounter = setInterval( function( )
        {
            /*
                If paused, just update the display and skip decrement
            */

            if ( csfPause )
            {
                timerEl.textContent = 'Paused';
                return;
            }

            csfCount--;
            timerEl.textContent = csfCount;

            if ( csfCount <= 0 )
            {
                const logObj = document.getElementById( 'csfLogNum' );
                const linesVal = document.getElementById( 'csfLines' ).value;
                const logNum = logObj ? `&lognum=${ logObj.value }` : '';

                csfSendReq( `${ csfScript }&lines=${ linesVal }${ logNum }` );
                csfCount = csfDuration;
            }
        }, 1000 );
    }

    /*
        Initialize display
    */

    timerEl.textContent = csfPause ? 'Paused' : csfCount;
}

/*
    Timer › Pause

    Toggles the automatic refresh pause state and updates button text
*/

function csfTimerPause( )
{
    /*
        Toggle pause state
    */

    csfPause = csfPause ? 0 : 1;

    /*
        Update button label
    */

    const pauseBtn = document.getElementById( 'csfPauseId' );
    if ( pauseBtn )
        pauseBtn.textContent = csfPause ? 'Continue' : 'Pause';
}

/*
    Timer › Refresh

    Forces an immediate refresh without waiting for timer to expire
*/

function csfTimerRefresh( ) 
{
    /*
        Temporarily unpause and run a one-time timer tick
    */

    const prevPause = csfPause;
    csfPause = 0;
    csfCount = 1;
    csfTimerInitialize( );
    csfPause = prevPause;

    /*
        Reset counter / update display
    */

    csfCount = csfDuration - 1;
    const timerEl = document.getElementById( 'csfTimer' );
    if ( timerEl ) timerEl.textContent = csfCount;
}

/*
    Gets and stores the current browser window width and height

	@note				Currently not utilized in main app
*/

function windowSize( )
{
    if ( typeof( window.innerHeight ) == 'number' )
    {
        csfHeight = window.innerHeight;
        csfWidth = window.innerWidth;
    }
    else if ( document.documentElement && ( document.documentElement.clientHeight ) )
    {
        csfHeight = document.documentElement.clientHeight;
        csfWidth = document.documentElement.clientWidth;
    }
    else if ( document.body && ( document.body.clientHeight ) )
    {
        csfHeight = document.body.clientHeight;
        csfWidth = document.body.clientWidth;
    }
}