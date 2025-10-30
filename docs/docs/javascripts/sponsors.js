document$.subscribe( async function( )
{
    const sponsorList = document.querySelector( '.mdx-sponsorship__list' );
    if ( !sponsorList )
        return;

    /*
        Clear existing content and add loaders for both sections
    */

    sponsorList.innerHTML = `
        <div class="sponsor-container" id="github-container">
            <h2>Insiders Participants</h2>

            <div class='sponsor-desc'> The following users have opted to participate in our <b>Insiders</b> program:</div>

            <div class="sponsor-loader" id="github-loader">
                <div class="dot"></div>
                <div class="dot"></div>
                <div class="dot"></div>
            </div>
            <div class="sponsor-avatars" id="github-avatars"></div>
        </div>

        <div class="sponsor-container" id="bmac-container">
            <h2>BuyMeACoffee Sponsors</h2>
    
            <div class='sponsor-desc'> The following users have contributed to CSF by becoming a <b>Sponsor</b>:</div>

            <div class="sponsor-loader" id="bmac-loader">
                <div class="dot"></div>
                <div class="dot"></div>
                <div class="dot"></div>
            </div>
            <div class="sponsor-avatars" id="bmac-avatars"></div>
        </div>
    `;

    /*
        Service > Insiders Members
    */
    
    try
    {
        const response = await fetch( 'https://license.configserver.dev/users' );

        if ( !response.ok )
            throw new Error( 'Failed to fetch GitHub sponsors: ' + response.status );

        /*
            Grab json data
        */

        const data              = await response.json( );

        /*
            Handle internal API errors (even if response.ok is true)
        */

        if ( data.error === true || data.success === false )
        {
            const msg = data?.message?.result || 'Unknown API error occurred';
            throw new Error( `API error: ${ msg }` );
        }

        /*
            Fetch Supporters
        */
        
        const loader            = document.getElementById('github-loader');
        const avatars           = document.getElementById('github-avatars');

        loader.style.display    = 'none'; // hide loader once data loads

        if ( !Array.isArray( data ) || data.length === 0 )
        {
            avatars.innerHTML   = '<em>No GitHub sponsors yet</em>';
        }
        else
        {
            data.forEach( sponsor =>
            {
                const username          = sponsor.github_id;
                if ( !username )
                    return;

                const githubUrl         = `https://github.com/${ username }`;
                const avatarUrl         = `https://github.com/${ username }.png?size=100`;

                const a                 = document.createElement('a');
                a.href                  = githubUrl;
                a.title                 = `@${ username }`;
                a.className             = 'mdx-sponsorship__item';
                a.target                = '_blank';
                a.rel                   = 'noopener';

                const img               = document.createElement('img');
                img.src                 = avatarUrl;
                img.alt                 = `@${ username }`;
                img.loading             = 'lazy';
                img.width               = 100;
                img.height              = 100;
                img.style.borderRadius  = '50%';
                img.style.boxShadow     = '0 2px 6px rgba(0,0,0,0.1)';

                a.appendChild( img );
                avatars.appendChild( a );
            });
        }
    }
    catch (err)
    {
        console.error( 'Error loading GitHub sponsors:', err );
        document.getElementById( 'github-avatars' ).innerHTML = '<em>Unable to load GitHub sponsors.</em>';
    }

    /*
        Service > BuyMeACoffee
    */

    try
    {
        const response = await fetch( 'https://sponsors.configserver.dev/buymeacoffee' );

        if ( !response.ok )
            throw new Error( 'Failed to fetch BuyMeACoffee supporters: ' + response.status );

        /*
            Grab json data
        */

        const data              = await response.json( );

        /*
            Handle internal API errors (even if response.ok is true)
        */

        if ( data.error === true || data.success === false )
        {
            const msg = data?.message?.result || 'Unknown API error occurred';
            throw new Error( `API error: ${ msg }` );
        }

        /*
            Fetch Supporters
        */

        const supporters        = Array.isArray( data.message.supporters ) ? data.message.supporters : [];
        const loader            = document.getElementById( 'bmac-loader' );
        const avatars           = document.getElementById( 'bmac-avatars' );

        loader.style.display    = 'none'; // hide loader once data loads

        if ( supporters.length === 0 )
        {
            avatars.innerHTML   = '<em>No BuyMeACoffee supporters yet</em>';
        }
        else
        {
            supporters.forEach( item =>
            {
                const username          = item.supporter_name || 'Unknown';
                const avatarUrl         = item.avatar_url || getBmacAvatar( username );

                const a                 = document.createElement( 'a' );
                a.href                  = '#';
                a.title                 = username;
                a.className             = 'mdx-sponsorship__item';
                a.target                = '_blank';
                a.rel                   = 'noopener';

                const img               = document.createElement( 'img' );
                img.src                 = avatarUrl;
                img.alt                 = username;
                img.loading             = 'lazy';
                img.width               = 100;
                img.height              = 100;
                img.style.borderRadius  = '50%';
                img.style.boxShadow     = '0 2px 6px rgba(0,0,0,0.1)';

                a.appendChild( img );
                avatars.appendChild( a );
            });
        }
    }
    catch (err)
    {
        console.error( 'Error loading BuyMeACoffee supporters:', err );
        document.getElementById( 'bmac-avatars' ).innerHTML = '<em>Unable to load BuyMeACoffee supporters.</em>';
    }
});

/*
    Helper: generate BuyMeACoffee avatar
*/

function getBmacAvatar( name )
{
    if ( !name )
        return `https://api.dicebear.com/9.x/avataaars/svg?seed=Unknown`;

    name = name.trim( ).replace(/^[^a-zA-Z0-9]+/, '');
    const words = name.split(' ');
    let initials = words.length >= 2
        ? words[ 0 ][ 0 ].toUpperCase( ) + words[ 1 ][ 0 ].toUpperCase( )
        : words[ 0 ].substring(0, 2).toUpperCase( );

    const colors        = [ 'FAC799', 'FFB3A0', 'EC9689', 'DEBBB9', 'EFC16D', 'FFD8CF' ];
    const colorIndex    = Array.from( name ).reduce( ( sum, c ) => sum + c.charCodeAt( 0 ), 0 ) % colors.length;
    const color         = colors[ colorIndex ];

    return `https://cdn.buymeacoffee.com/uploads/profile_pictures/default/v2/${ color }/${ initials }.png@200w_0e.webp`;
}
