interface Env {
  OAUTH_CLIENT_ID: string;
  OAUTH_CLIENT_SECRET: string;
}

interface GitHubUser {
  login: string;
  id: number;
  avatar_url: string;
  name: string;
}

// Helper function to generate random hex string using Web Crypto API
function generateRandomHex(length: number): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers for all responses - restricted to the main site
    const corsHeaders = {
      'Access-Control-Allow-Origin': 'https://soundofsimone.no',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Auth endpoint - initiate OAuth flow
    if (path === '/auth') {
      const clientId = env.OAUTH_CLIENT_ID;
      
      if (!clientId) {
        return new Response('OAuth Client ID not configured', { 
          status: 500,
          headers: corsHeaders 
        });
      }

      const state = generateRandomHex(16);
      const redirectUri = `https://${url.hostname}/callback`;
      
      const authUrl = new URL('https://github.com/login/oauth/authorize');
      authUrl.searchParams.set('client_id', clientId);
      authUrl.searchParams.set('redirect_uri', redirectUri);
      authUrl.searchParams.set('scope', 'repo,user');
      authUrl.searchParams.set('state', state);

      return Response.redirect(authUrl.toString(), 302);
    }

    // Callback endpoint - exchange code for token
    if (path === '/callback') {
      const code = url.searchParams.get('code');
      const state = url.searchParams.get('state');

      if (!code) {
        return new Response('Missing authorization code', { 
          status: 400,
          headers: corsHeaders 
        });
      }

      const clientId = env.OAUTH_CLIENT_ID;
      const clientSecret = env.OAUTH_CLIENT_SECRET;

      if (!clientId || !clientSecret) {
        return new Response('OAuth credentials not configured', { 
          status: 500,
          headers: corsHeaders 
        });
      }

      try {
        // Exchange code for access token
        const tokenResponse = await fetch('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: JSON.stringify({
            client_id: clientId,
            client_secret: clientSecret,
            code: code,
            redirect_uri: `https://${url.hostname}/callback`,
          }),
        });

        const tokenData = await tokenResponse.json() as any;

        if (tokenData.error) {
          console.error('OAuth error:', tokenData);
          return new Response(`OAuth error: ${tokenData.error_description || tokenData.error}`, { 
            status: 400,
            headers: corsHeaders 
          });
        }

        const accessToken = tokenData.access_token;

        if (!accessToken) {
          return new Response('Failed to obtain access token', { 
            status: 500,
            headers: corsHeaders 
          });
        }

        // Validate the token by making a test API call to GitHub
        try {
          const userResponse = await fetch('https://api.github.com/user', {
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Decap-OAuth-Proxy',
            },
          });

          if (!userResponse.ok) {
            console.error('Token validation failed:', userResponse.status, userResponse.statusText);
            return new Response(`Token validation failed: ${userResponse.statusText}`, { 
              status: 401,
              headers: corsHeaders 
            });
          }

          // Token is valid if we can successfully fetch user info
          const userData = await userResponse.json() as GitHubUser;
          console.log('Token validated successfully for user:', userData.login);
        } catch (validationError) {
          console.error('Error validating token:', validationError);
          return new Response('Failed to validate access token', { 
            status: 500,
            headers: corsHeaders 
          });
        }

        // Prepare token data as JSON to safely embed in HTML
        const tokenDataJson = JSON.stringify({ 
          token: accessToken, 
          provider: 'github' 
        });

        // Return success page that sends token back to opener window
        const html = `
<!DOCTYPE html>
<html>
<head>
  <title>Authorization Successful</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      background: #f5f5f5;
    }
    .container {
      text-align: center;
      padding: 2rem;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .success {
      color: #22c55e;
      font-size: 3rem;
      margin-bottom: 1rem;
    }
    h1 {
      color: #333;
      margin-bottom: 0.5rem;
    }
    p {
      color: #666;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="success">✓</div>
    <h1>Authorization Successful</h1>
    <p>You can close this window now.</p>
  </div>
  <script>
    (function() {
      const tokenData = ${tokenDataJson};
      const targetOrigin = 'https://soundofsimone.no';
      
      function receiveMessage(_message) {
        window.opener.postMessage(
          'authorization:github:success:' + JSON.stringify(tokenData),
          targetOrigin
        );
        window.removeEventListener('message', receiveMessage, false);
      }
      window.addEventListener('message', receiveMessage, false);
      
      window.opener.postMessage('authorizing:github', targetOrigin);
      
      // Auto-close after 2 seconds
      setTimeout(function() {
        window.close();
      }, 2000);
    })();
  </script>
</body>
</html>
        `;

        return new Response(html, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'text/html',
          },
        });

      } catch (error) {
        console.error('Error exchanging code for token:', error);
        return new Response('Internal server error', { 
          status: 500,
          headers: corsHeaders 
        });
      }
    }

    // Success endpoint (optional, for direct access)
    if (path === '/success') {
      const provider = url.searchParams.get('provider') || 'github';
      const targetOrigin = 'https://soundofsimone.no';
      const html = `
<!DOCTYPE html>
<html>
<head>
  <title>Authorization Complete</title>
</head>
<body>
  <script>
    if (window.opener) {
      window.opener.postMessage('authorization:${provider}:success', '${targetOrigin}');
      window.close();
    }
  </script>
  <p>Authorization complete. You can close this window.</p>
</body>
</html>
      `;
      
      return new Response(html, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/html',
        },
      });
    }

    // Default response
    return new Response('OAuth Proxy for Decap CMS', { 
      headers: corsHeaders 
    });
  },
};
