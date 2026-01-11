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

            <div class="sponsor-loader" id="insiders-loader">
                <div class="dot"></div>
                <div class="dot"></div>
                <div class="dot"></div>
            </div>
            <div class="sponsor-avatars" id="insiders-avatars"></div>
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
        Service › Insiders Members

        List of Insiders members who have activated a license key for the insider's branch
    */
    
    try
    {
        const response = await fetch( 'https://license.configserver.dev/insiders' );

        if ( !response.ok )
            throw new Error( 'Failed to fetch Insiders members: ' + response.status );

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
            Extract sponsors list
        */

        const users             = data?.message?.result || [];

        /*
            Fetch Github Sponsors
        */
        
        const loader            = document.getElementById( 'insiders-loader' ) ;
        const avatars           = document.getElementById( 'insiders-avatars' );
        loader.style.display    = 'none'; // hide loader once data loads

        if ( !Array.isArray( users ) || users.length === 0 )
        {
            avatars.innerHTML   = '<em>No GitHub sponsors yet</em>';
        }
        else
        {
            users.forEach(sponsor =>
            {
                const username = sponsor.github_id;
                if ( !username )
                    return;

                const githubUrl             = `https://github.com/${ username }`;
                const avatarUrl             = `https://github.com/${ username }.png?size=100`;

                const a                     = document.createElement( 'a' );
                a.href                      = githubUrl;
                a.title                     = `@${ username }`;
                a.className                 = 'mdx-sponsorship__item';
                a.target                    = '_blank';
                a.rel                       = 'noopener';

                const img                   = document.createElement( 'img' );
                img.src                     = avatarUrl;
                img.alt                     = `@${ username }`;
                img.loading                 = 'lazy';
                img.width                   = 100;
                img.height                  = 100;
                img.style.borderRadius      = '50%';
                img.style.boxShadow         = '0 2px 6px rgba(0,0,0,0.1)';

                a.appendChild( img );
                avatars.appendChild( a );
            });
        }
    }
    catch ( err )
    {
        console.error( 'Error loading Insiders members with valid license:', err );
        document.getElementById( 'insiders-avatars' ).innerHTML = '<em>Unable to load GitHub sponsors.</em>';
    }

    /*
        Service › BuyMeACoffee Sponsors

        Returns a list of all BuyMeACoffee sponsors who have contributed to the project. Will display
        an avatar, and their username on the site.
    */

    try
    {
        const response = await fetch( 'https://license.configserver.dev/buymeacoffee' );

        if ( !response.ok )
            throw new Error( 'Failed to fetch BuyMeACoffee sponsors: ' + response.status );

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
            BuyMeACoffee > Fetch Sponsors
        */

        const sponsors          = Array.isArray( data.message.sponsors ) ? data.message.sponsors : [];
        const loader            = document.getElementById( 'bmac-loader' );
        const avatars           = document.getElementById( 'bmac-avatars' );
        loader.style.display    = 'none'; // hide loader once data loads

        if ( sponsors.length === 0 )
        {
            avatars.innerHTML   = '<em>No BuyMeACoffee sponsors yet</em>';
        }
        else
        {
            sponsors.forEach( item =>
            {
                const username              = item.supporter_name || 'Unknown';
                const avatarUrl             = item.avatar_url || getMemberAvatar( username );

                const a                     = document.createElement( 'a' );
                a.href                      = '#';
                a.title                     = username;
                a.className                 = 'mdx-sponsorship__item';
                a.target                    = '_blank';
                a.rel                       = 'noopener';

                const img                   = document.createElement( 'img' );
                img.src                     = avatarUrl;
                img.alt                     = username;
                img.loading                 = 'lazy';
                img.width                   = 100;
                img.height                  = 100;
                img.style.borderRadius      = '50%';
                img.style.boxShadow         = '0 2px 6px rgba(0,0,0,0.1)';

                a.appendChild( img );
                avatars.appendChild( a );
            });
        }
    }
    catch (err)
    {
        console.error( 'Error loading BuyMeACoffee sponsors:', err );
        document.getElementById( 'bmac-avatars' ).innerHTML = '<em>Unable to load BuyMeACoffee sponsors.</em>';
    }
});

/*
    Helper: generate BuyMeACoffee avatar
*/

function getMemberAvatar( name )
{
    if ( !name )
        return `https://api.dicebear.com/9.x/avataaars/svg?seed=Unknown`;

    name                = name.trim( ).replace(/^[^a-zA-Z0-9]+/, '');
    const words         = name.split(' ');
    let initials        = words.length >= 2
                            ? words[ 0 ][ 0 ].toUpperCase( ) + words[ 1 ][ 0 ].toUpperCase( )
                            : words[ 0 ].substring(0, 2).toUpperCase( );

    const colors        = [ 'FAC799', 'FFB3A0', 'EC9689', 'DEBBB9', 'EFC16D', 'FFD8CF' ];
    const colorIndex    = Array.from( name ).reduce( ( sum, c ) => sum + c.charCodeAt( 0 ), 0 ) % colors.length;
    const color         = colors[ colorIndex ];

    return `https://cdn.buymeacoffee.com/uploads/profile_pictures/default/v2/${ color }/${ initials }.png@200w_0e.webp`;
}
