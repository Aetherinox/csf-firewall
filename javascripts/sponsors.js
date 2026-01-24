/*
    @app                    ConfigServer Firewall & Security (CSF)
                            Login Failure Daemon (LFD)
    @service                Mkdocs
    @script                 insiders.js
    @desc                   Populate Insiders & Sponsors lists
    @website                https://configserver.dev
    @docs                   https://docs.configserver.dev
    @url                    https://docs.configserver.dev/insiders/sponsors/
    @repo                   https://github.com/Aetherinox/csf-firewall
    @copyright              Copyright (C) 2025-2026 Aetherinox
    @license                MIT
    @updated                01.24.2026

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

/*
    General Settings

    urlMembership           avatar url if user has no link to their own profile.
    urlApi                  api url to pull insiders & sponsors
    urlAvDicebear           dicebear api for avatar generation
    urlAvBuyMeACoffee       BuyMeACoffee avatar storage
*/

const urlMembership         = 'https://buymeacoffee.com/aetherinox/membership';
const urlApi                = 'https://license.configserver.dev';
const urlAvDicebear         = 'https://api.dicebear.com/9.x';
const urlAvBuyMeACoffee     = 'https://cdn.buymeacoffee.com/uploads/profile_pictures/default/v2';

/*
    Preloader › New

    Create preloader dots to show before sponsors and insider lists are populated.

    @param  num                 int                 Number of dots
    @return                     HTMLElement
*/

function newPreloader( num = 6 )
{
    const elm_loader        = document.createElement( 'div' );
    elm_loader.className    = 'membership-loader';

    for ( let i = 0; i < num; i++ )
    {
        const elm_dot       = document.createElement( 'div' );
        elm_dot.className   = 'dot';
        elm_dot.style.animationDelay = `${ i * 0.15 }s`;

        elm_loader.appendChild( elm_dot );
    }

    return elm_loader;
}

/*
    Block › New

    Create main container which holds Insiders and Sponsors lists.

    @param  id                  str                 Block id (for elements)
            title               str                 Block title
            desc                str                 Section description
    @return                     HTMLElement
*/

function newBlock( { id, title, desc } )
{
    const elm_container         = document.createElement( 'div' );
    elm_container.className     = 'membership-container';
    elm_container.id            = `${ id }-container`;

    const elm_h2                = document.createElement( 'h2' );
    elm_h2.textContent          = title;
    elm_container.appendChild   ( elm_h2 );

    const elm_desc              = document.createElement( 'div' );
    elm_desc.className          = 'membership-desc';
    elm_desc.textContent        = desc;
    elm_container.appendChild   ( elm_desc );

    const elm_loader            = newPreloader();
    elm_loader.id               = `${ id }-loader`;
    elm_container.appendChild   ( elm_loader );

    const elm_av                = document.createElement( 'div' );
    elm_av.className            = 'membership-avatars';
    elm_av.id                   = `${ id }-avatars`;
    elm_container.appendChild   ( elm_av );

    return elm_container;
}

/*
    Helper › Add Delay

    Used to add a delay to preloader. Was only used for testing. Should be
    low for production.

    @param  ms                  int                 Delay in milliseconds
    @return                     Promise
*/

function addDelay( ms = 1000 )
{
    return new Promise( resolve => setTimeout( resolve, ms ) );
}

/*
    Block › Populate

    Populate main container with list of Insiders & Sponsor members.

    @param  urlApi              str                 Base API url
            endpoint            str                 API endpoint to fetch list from, used as class for elements.
            avatarKey           str                 JSOn key for user avatar
            displayName         str                 Name to show list as
            demo                bool                Keep us from spamming real API endpoints.
                                                        demo: true          Use local json response (static)
                                                        demo: false         Query real API endpoint (dynamic) 
            delayLoad           int                 Preloader delay in milliseconds
    @return                     void
*/

async function populateBlock( { urlApi, endpoint, avatarKey = 'name', displayName = 'members', demo = false, delayLoad = 1000 } )
{
    const elm_loader            = document.getElementById( `${ endpoint }-loader` );
    const elm_avatars           = document.getElementById( `${ endpoint }-avatars` );
    const delayDur              = addDelay( delayLoad );

    elm_loader.style.display    = '';
    elm_avatars.textContent     = '';

    try
    {
        // ?demo param serves local JSON data, prevent spamming real api endpoint (data not real)
        const url           = `${ urlApi }/${ endpoint }${ demo ? '?demo' : '' }`;
        const response      = await fetch( url );

        if ( !response.ok )
            throw new Error( `Failed to fetch /${ endpoint }: ${ response.status }` );

        // As of Jan 2026, only data.success available; data.error removed
        const data          = await response.json( );
        if ( data.success === false )
        {
            const msg = data?.message?.[ endpoint ] || 'Unknown API error';
            throw new Error( `API error: ${ msg }` );
        }

        const list = Array.isArray( data.message?.[ endpoint ] )
            ? data.message[ endpoint ]
            : [];

        await delayDur;
        elm_loader.style.display = 'none';

        if ( !list.length )
            return newStatus( elm_avatars, `No ${ displayName } yet` );

        /*
            Loop json response of members
        */

        list.forEach( item =>
        {
            const username              = item[ avatarKey ] || null;
            const profileUrl            = item.profile_url || urlMembership;
            const avatarUrl             = item.avatar_url || newAvatar( username );

            const elm_a                 = document.createElement( 'a' );
            elm_a.href                  = profileUrl;
            elm_a.title                 = username;
            elm_a.className             = 'mdx-sponsorship__item';
            elm_a.target                = '_blank';
            elm_a.rel                   = 'noopener';

            const elm_img               = document.createElement( 'img' );
            elm_img.src                 = avatarUrl;
            elm_img.alt                 = username;
            elm_img.loading             = 'lazy';
            elm_img.width               = 100;
            elm_img.height              = 100;
            elm_img.style.borderRadius  = '50%';
            elm_img.style.boxShadow     = '0 2px 6px rgba(0,0,0,0.1)';

            elm_a.appendChild( elm_img );
            elm_avatars.appendChild( elm_a );
        });

    }
    catch ( err )
    {
        console.error( `Error loading ${ displayName }:`, err );
        newStatus( elm_avatars, `Unable to load list ${ displayName }.` );
    }
}

/*
    Generate Seed

    Used with Dicebear to generate an avatar if they don't have one for Github.
    Custom length in case needed for larger numbers later.

    @param  len                 int                 length of seed
    @return                     str
*/

function rndSeed( len = 10 )
{
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let seed    = '';

    for ( let i = 0; i < len; i++ )
    {
        seed += chars.charAt( Math.floor( Math.random( ) * chars.length ) );
    }

    return seed;
}

/*
    Interface > New Avatar

    Usually our API gives us the avatar URL. This function serves as a backup 
    for generating avatars. 
    
    If a name is provided, use BuyMeACoffee, if no name, Dicebear used as backup.

    @ref                        https://dicebear.com/how-to-use/http-api/
                                https://dicebear.com/styles/
                                https://dicebear.com/styles/pixel-art/
                                https://dicebear.com/playground/

                                https://img.buymeacoffee.com/

    @param  name                str                 Name of user
            seed                str                 Optional seed to generate 
                                                        avatar from. Randomly generated if none specified.
            styleName           str                 The type of avatar to generate from Dicebear
                                                        adventurer          avataaars
                                                        bottts              fun-emoji
                                                        glass               icons
                                                        identicon           initials

    @return                     str
*/

function newAvatar( name, seed = null, styleName = 'pixel-art' )
{
    if ( !name )
    {
        const genSeed = seed || rndSeed( );
        return `${ urlAvDicebear }/${ styleName }/svg?seed=${ encodeURIComponent( genSeed ) }`;
    }

    /*
        Dicebear allows any name.

        BuyMeACoffee takes the first two letters of the user's name, and passes those
            to generate an avatar.

            If a name contains numbers, manipulate to pick letters only based on the
            position of the number:
                X1      =>  XX
                1A2B    =>  AB
    */

    name                = name.trim( ).replace( /^[^a-zA-Z0-9]+/, '' );
    const words         = name.split( ' ' );
    const name_first    = words[ 0 ];

    let initials        = '';
    let lastLetter      = '';

    for ( let i = 0; i < name_first.length; i++ )
    {
        const char = name_first[ i ].toUpperCase( );
        if ( /[A-Z]/.test( char ) )
        {
            initials    += char;
            lastLetter  = char;
        }
        else if ( /[0-9]/.test( char ) )
        {
            initials += lastLetter;                 // repeat last letter if currnet char is num
        }
    }

    /*
        BuyMeACoffee › Define initials
    */

    initials = initials.substring( 0, 2 );

    /*
        BuyMeACoffee › Color parameters
    */

    const colors        = [ 'FAC799', 'FFB3A0', 'EC9689', 'DEBBB9', 'EFC16D', 'FFD8CF' ];
    const colorIndex    = Array.from( name ).reduce( ( sum, c ) => sum + c.charCodeAt( 0 ), 0 ) % colors.length;
    const color         = colors[ colorIndex ];

    return `${ urlAvBuyMeACoffee }/${ color }/${ initials }.png@200w_0e.webp`;
}

/*
    Show Status

    @param  container           HTMLElement         Parent DOM element
            msg                 str                 Message to show
    @return                     void
*/

function newStatus( elm_container, msg )
{
    elm_container.textContent   = '';
    const elm_em                = document.createElement( 'em' );
    elm_em.textContent          = msg;

    elm_container.appendChild( elm_em );
}

/*
    Subscribe to stream
*/

document$.subscribe( async function( )
{
    const parentBlock = document.querySelector( '.mdx-sponsorship__list' );
    if ( !parentBlock ) return;

    /*
        Create Insiders & Sponsor blocks
    */

    parentBlock.textContent = '';
    parentBlock.appendChild( newBlock(
    {
        id:         'insiders',
        title:      'Insiders Participants',
        desc:       'The following users have opted to participate in our Insiders program:'
    }));

    parentBlock.appendChild( newBlock(
    {
        id:         'sponsors',
        title:      'Sponsors',
        desc:       'The following users have contributed to CSF by becoming a Sponsor:'
    }));

    /*
        Block › Populate

        Populates each block in parallel to show Insiders and Sponsors in lists.

        Allow each block to customize urlApi, if we need alternative routes
        in the future.

        @param  urlApi              str                 Base API url
                endpoint            str                 API endpoint to fetch list from, used as class for elements.
                avatarKey           str                 JSOn key for user avatar
                displayName         str                 Name to show list as
                demo                bool                Keep us from spamming real API endpoints.
                                                            demo: true          Use local json response (static)
                                                            demo: false         Query real API endpoint (dynamic) 
                delayLoad           int                 Preloader delay in milliseconds (optional or 1 second)
    */

    await Promise.all(
    [
        populateBlock(
        {
            urlApi,
            endpoint:       'insiders',
            avatarKey:      'name',
            displayName:    'Insiders'
        }),
        populateBlock(
        {
            urlApi,
            endpoint:       'sponsors',
            avatarKey:      'supporter_name',
            displayName:    'Sponsors'
        })
    ]);

});
