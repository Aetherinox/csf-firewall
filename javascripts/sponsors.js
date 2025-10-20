document$.subscribe( async function( )
{
    /*
        Load sponsor data dynamically into the sponsorship list
    */

    const sponsorList = document.querySelector( '.mdx-sponsorship__list' );
    if ( !sponsorList )
    {
        return; // No sponsor container found on this page
    }

    /*
        Create a temporary loading spinner
    */

    sponsorList.innerHTML = `
        <div class="sponsor-loader">
            <div class="dot"></div>
            <div class="dot"></div>
            <div class="dot"></div>
        </div>
    `;

    try
    {
        /*
            Fetch sponsor JSON
        */

        const response = await fetch( 'https://license.configserver.dev/users' );
        if ( !response.ok )
        {
            throw new Error( 'Failed to fetch sponsor list: ' + response.status );
        }

        const sponsors = await response.json( );

        /*
            Clear preloader
        */

        sponsorList.innerHTML = '';

        /*
            If no sponsors found
        */
  
        if ( !Array.isArray( sponsors ) || sponsors.length === 0 )
        {
            sponsorList.innerHTML = '<em>No sponsors yet</em>';
            return;
        }

        /*
            Create sponsor entries
        */

        sponsors.forEach( sponsor =>
        {
            const username = sponsor.github_id;
            if (!username) return;

            const githubUrl = `https://github.com/${ username }`;
            const avatarUrl = `https://github.com/${ username }.png?size=100`;

            const a = document.createElement( 'a' );
            a.href = githubUrl;
            a.title = `@${username}`;
            a.className = 'mdx-sponsorship__item';
            a.target = '_blank';
            a.rel = 'noopener';

            const img = document.createElement( 'img' );
            img.src = avatarUrl;
            img.alt = `@${username}`;
            img.loading = 'lazy';
            img.width = 100;
            img.height = 100;
            img.style.borderRadius = '50%';
            img.style.margin = '6px';
            img.style.boxShadow = '0 2px 6px rgba(0,0,0,0.1)';

            a.appendChild( img );
            sponsorList.appendChild( a );
        });
    }
    catch (err)
    {
        console.error( 'Error loading sponsors:', err );
        sponsorList.innerHTML = '<em>Unable to load sponsor list.</em>';
    }
});
