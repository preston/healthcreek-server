require 'uri'

class IdentityProvidersController < ApplicationController

    load_resource :identity_provider
    skip_before_action	:authenticate_identity! #,	except: :destroy
    skip_authorization_check

    def launch
        @script = <<EOF
        // Change this to the ID of the client that you registered with the SMART on FHIR authorization server.
        // This is set by browserify during compilation depending on the environment
        // and is ultimately read from the system's env variables.
        var clientId = "#{@identity_provider.client_id}"
        // For demonstration purposes, if you registered a confidential client
        // you can enter its secret here. The demo app will pretend it's a confidential
        // app (in reality it cannot be confidential, since it cannot keep secrets in the
        // browser)
        var secret = "#{@identity_provider.client_secret}";    // set me, if confidential
        // These parameters will be received at launch time in the URL
        var serviceUri = getUrlParameter("iss");
        var launchContextId = getUrlParameter("launch");
        // The scopes that the app will request from the authorization server
        // encoded in a space-separated string:
        //      1. permission to read all of the patient's record
        //      2. permission to launch the app in the specific context
        var scope = "launch user/*.* openid profile offline_access";
        / var scope = [
          //- "patient/*.read",
          //- launch user/*.* openid profile offline_access
        /   "launch",
        /   "openid",
        /   "profile"
        / ].join(" ");
        // Generate a unique session key string (here we just generate a random number
        // for simplicity, but this is not 100% collision-proof)
        var state = Math.round(Math.random() * 100000000).toString();
        // To keep things flexible, let's construct the launch URL by taking the base of the
        // current URL and replace "launch.html" with "index.html".
        var launchUri = window.location.protocol + "//" + window.location.host + window.location.pathname;
        var redirectUri = launchUri.replace("launch.html", "");
        // FHIR Service Conformance Statement URL
        var conformanceUri = serviceUri + "/metadata"
        // Let's request the conformance statement from the SMART on FHIR API server and
        // find out the endpoint URLs for the authorization server
        $.get(conformanceUri, function (r) {
          var authUri,
            tokenUri;
          var smartExtension = r.rest[0].security.extension.filter(function (e) {
            return (e.url === "http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris");
          });
          smartExtension[0].extension.forEach(function (arg, index, array) {
            if (arg.url === "authorize") {
              authUri = arg.valueUri;
            } else if (arg.url === "token") {
              tokenUri = arg.valueUri;
            }
          });
          // retain a couple parameters in the session for later use
          localStorage[state] = JSON.stringify({
            clientId: clientId,
            serviceUri: serviceUri,
            redirectUri: redirectUri,
            tokenUri: tokenUri
          });
          // finally, redirect the browser to the authorizatin server and pass the needed
          // parameters for the authorization request in the URL
          window.location.href = authUri + "?" +
            "response_type=code&" +
            "client_id=" + encodeURIComponent(clientId) + "&" +
            "scope=" + encodeURIComponent(scope) + "&" +
            "redirect_uri=" + encodeURIComponent(redirectUri) + "&" +
            "aud=" + encodeURIComponent(serviceUri) + "&" +
            "launch=" + launchContextId + "&" +
            "state=" + state;
        }, "json");
        // Convenience function for parsing of URL parameters
        // based on http://www.jquerybyexample.net/2012/06/get-url-parameters-using-jquery.html
        function getUrlParameter(sParam) {
          var sPageURL = window.location.search.substring(1);
          var sURLVariables = sPageURL.split('&');
          for (var i = 0; i < sURLVariables.length; i++) {
            var sParameterName = sURLVariables[i].split('=');
            if (sParameterName[0] == sParam) {
              var res = sParameterName[1].replace(/\\+/g, '%20');
              return decodeURIComponent(res);
            }
          }
        }
EOF
        # render layout: false
    end
    
    def launch
        idp = @identity_provider
        session['provider_id'] = idp.id
        # uri = URI(idp.configuration['authorization_endpoint'])
        issuer = params['iss']
        launch_id = params['launch']
        scope = params['scope'] || 'patient/*.read openid email profile'
        query = {
            redirect_uri:	callback_url,
            # state: 			new_nonce,
            response_type: 	:code,
            access_type: 	:offline,
            # aud: idp.client_id,
            client_id: 		idp.client_id,
            # scope: idp.scopes
            scope: 			scope,
            aud: issuer,
            launch: launch_id
            # scope: 			'launch/encounter person/*.read launch openid patient/*.read profile'
            # scope: 			'phone email address launch/encounter person/*.read launch openid patient/*.read profile'
        }
        uri.query = URI.encode_www_form(query)
        redirect_to uri.to_s
    end

end
