<!---
	Name: instagramCFC
	Author: Andy Matthews
	Website: http://www.andyMatthews.net || http://instagramCFC.riaforge.org
	API Docs: http://instagr.am/developer/
	Created: 08/08/2011
	Last Updated: 08/20/2011
	History:
		08/08/2011: Initial creation of instagramCFC
	Version: Listed in contructor
--->
<cfcomponent hint="CFC allowing users to tap into the Instagram photo sharing API" displayname="instagramCFC" output="false">

	<cfscript>
		VARIABLES.version = '.1';
		VARIABLES.appName = 'instagramCFC';
		VARIABLES.baseURL = 'https://api.instagram.com/v1';
		VARIABLES.lastUpdated = CreateDate(2011,08,20);
		VARIABLES.client_id = '';
		VARIABLES.access_token = '';
	</cfscript>

	<!---
		################################################################
		##	 INTERNAL METHODS ###########################################
		################################################################
	--->
	<cffunction name="init" description="Initializes the CFC, returns itself" returntype="any" access="public" output="false">
		<cfargument name="client_id" type="string" required="false" >
		<cfargument name="access_token" type="string" required="false">

		<cfscript>
			if ( structKeyExists(ARGUMENTS,'client_id') ) VARIABLES.client_id = ARGUMENTS.client_id;
			if ( structKeyExists(ARGUMENTS,'access_token') ) VARIABLES.access_token = ARGUMENTS.access_token;
			if ( VARIABLES.client_id == '' && VARIABLES.access_token == '' ) {
				return pkgStruct('', 0, 'You must provide either client_id or access_token.');
			}
		</cfscript>

		<cfreturn THIS>
	</cffunction>

	<cffunction name="currentVersion" description="Returns current version" returntype="string" access="public" output="false">
		<cfreturn VARIABLES.version>
	</cffunction>

	<cffunction name="lastUpdated" description="Returns last updated date" returntype="date" access="public" output="false">
		<cfreturn VARIABLES.lastUpdated>
	</cffunction>

	<cffunction name="introspect" description="Returns detailed info about this CFC" returntype="struct" access="public" output="false">
		<cfreturn getMetaData(this)>
	</cffunction>

	<cffunction name="call" description="The actual http call to instagram" returntype="string" access="private" output="false">
		<cfargument name="attr" required="true" type="struct">
		<cfargument name="params" required="true" type="struct">

		<cfscript>
			var LOCAL = {};
			var cfhttp = {};
			// what fieldtype will this be?
			LOCAL['fieldType'] = iif( ListFind('GET,DELETE', ARGUMENTS.attr['method']), De('URL'), De('formField') );
			LOCAL['params'] = Duplicate(ARGUMENTS.params);
			if ( VARIABLES.access_token NEQ '') LOCAL['params']['access_token'] = VARIABLES.access_token;
			if ( VARIABLES.client_id NEQ '') LOCAL['params']['client_id'] = VARIABLES.client_id;
		</cfscript>
		<!---<cfdump var="#cfhttp.fileContent.toString()#" abort="true">--->
		<cfhttp attributecollection="#ARGUMENTS.attr#">
			<cfloop collection="#LOCAL['params']#" item="LOCAL.key">
				<cfhttpparam name="#LOCAL.key#" type="#LOCAL['fieldType']#" value="#LOCAL['params'][LOCAL.key]#">
			</cfloop>
		</cfhttp>
		<!---<cfdump var="#cfhttp.fileContent.toString()#" abort="true">--->
		<cfreturn cfhttp.fileContent.toString()>
	</cffunction>

	<cffunction name="prep" description="Prepares data for call to instagram servers" returntype="struct" access="private" output="false">
		<cfargument name="config" type="struct" required="true">

		<cfscript>
			var LOCAL = {};
			LOCAL['cfdata'] = {};
			LOCAL['attributes'] = {};
			LOCAL['returnStruct'] = {};

			// finish setting up the attributes for the http call
			LOCAL['attributes']['url'] = ARGUMENTS['config']['url'];
			LOCAL['attributes']['method'] = ARGUMENTS['config']['method'];

			try {
				LOCAL['jsondata'] = call(LOCAL['attributes'], ARGUMENTS['config']['params']);
				LOCAL['cfdata'] = DeserializeJson(LOCAL['jsondata']);

				//writedump(var=LOCAL,abort=true);

				// were there any errors?
				if (StructCount(LOCAL.cfdata.meta) AND LOCAL.cfdata.meta.code EQ 200) {
					// no errors, proceed
					if (ARGUMENTS['config']['format'] EQ 'json') {
						LOCAL.returnStruct = pkgStruct(LOCAL['jsondata'], 1, 'Request successful');
					} else {
						LOCAL.returnStruct = pkgStruct(LOCAL['cfdata'], 1, 'Request successful');
					}
				} else {
					if ( IsDefined('LOCAL.cfdata.meta.errorDetail') ) {
						// yes there were, get the details
						return pkgStruct('', 0, LOCAL['cfdata']['meta']['errorDetail']);
					} else {
						return pkgStruct('', 0, 'An error occurred. Please check your parameters and try your request again.');
					}
				}
			} catch(any e) {
				//set success and message value
				return pkgStruct('', 0, 'An error occurred. Please check your parameters and try your request again.');
			}
		</cfscript>

		<cfreturn LOCAL.returnStruct>
	</cffunction>

	<cffunction name="pkgStruct" description="packages data into a struct for return to user" returntype="struct" access="private" output="false">
		<cfargument name="data" type="any" required="true">
		<cfargument name="success" type="boolean" required="true">
		<cfargument name="message" type="string" required="true">
		<cfscript>
				var LOCAL['return'] = {};
				LOCAL['return']['data'] = ARGUMENTS.data;
				LOCAL['return']['success'] = ARGUMENTS.success;
				LOCAL['return']['message'] = ARGUMENTS.message;
		</cfscript>
		<cfreturn LOCAL['return']>
	</cffunction>





	<!---
		################################################################
		##	 USER METHODS ###############################################
		################################################################
	--->
	<cffunction name="user" description="Get basic information about a user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userFeed" description="See the authenticated user's feed" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="max_id" type="string" required="false" hint="Return media earlier than this max_id">
		<cfargument name="min_id" type="string" required="false" hint="Return media later than this max_id">
		<cfargument name="count" type="numeric" required="false" hint="Count of media to return">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/self/feed';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'max_id') ) LOCAL['config']['params']['max_id'] = ARGUMENTS.max_id;
			if ( StructKeyExists(ARGUMENTS,'min_id') ) LOCAL['config']['params']['min_id'] = ARGUMENTS.min_id;
			if ( StructKeyExists(ARGUMENTS,'count') ) LOCAL['config']['params']['count'] = ARGUMENTS.count;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userRecent" description="Get the most recent media published by a user." returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="user_id" type="string" required="true" hint="The id of the user you're interested in">
		<cfargument name="max_id" type="string" required="false" hint="Return media earlier than this max_id">
		<cfargument name="min_id" type="string" required="false" hint="Return media later than this max_id">
		<cfargument name="count" type="numeric" required="false" hint="Count of media to return">
		<cfargument name="min_timestamp" type="string" required="false" hint="Return media after this UNIX timestamp">
		<cfargument name="max_timestamp" type="string" required="false" hint="Return media before this UNIX timestamp">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/media/recent';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'max_id') ) LOCAL['config']['params']['max_id'] = ARGUMENTS.max_id;
			if ( StructKeyExists(ARGUMENTS,'min_id') ) LOCAL['config']['params']['min_id'] = ARGUMENTS.min_id;
			if ( StructKeyExists(ARGUMENTS,'count') ) LOCAL['config']['params']['count'] = ARGUMENTS.count;
			if ( StructKeyExists(ARGUMENTS,'min_timestamp') ) LOCAL['config']['params']['min_timestamp'] = ARGUMENTS.min_timestamp;
			if ( StructKeyExists(ARGUMENTS,'max_timestamp') ) LOCAL['config']['params']['max_timestamp'] = ARGUMENTS.max_timestamp;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userLiked" description="See the authenticated user's feed" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="max_like_id" type="string" required="false" hint="Return media liked before this id">
		<cfargument name="count" type="numeric" required="false" hint="Count of media to return">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/self/media/liked';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'max_like_id') ) LOCAL['config']['params']['max_like_id'] = ARGUMENTS.max_like_id;
			if ( StructKeyExists(ARGUMENTS,'count') ) LOCAL['config']['params']['count'] = ARGUMENTS.count;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userSearch" description="Search for a user by name" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="q" type="string" required="true" hint="A name to search for">
		<cfargument name="count" type="numeric" required="false" hint="Number of users to return">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'q') ) LOCAL['config']['params']['q'] = ARGUMENTS.q;
			if ( StructKeyExists(ARGUMENTS,'count') ) LOCAL['config']['params']['count'] = ARGUMENTS.count;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 RELATIONSHIP METHODS ###############################################
		################################################################
	--->
	<cffunction name="userFollows" description="Get the list of users this user follows" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/follows';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userFollowedBy" description="Get the list of users this user is followed by" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/followed-by';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userFollowRequest" description="List the users who have requested this user's permission to follow" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/self/requested-by';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userRelationship" description="Get/set information about the current user's relationship (follow/following/etc) to another user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="action" type="string" required="false" hint="Only used to change relationship. One of follow/unfollow/block/unblock/approve/deny.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			if ( StructKeyExists(ARGUMENTS,'action') ) {
				LOCAL['config']['method'] = 'POST';
			} else {
				LOCAL['config']['method'] = 'GET';
			}
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/relationship';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'action') ) {
				if ( ListFindNoCase('follow,unfollow,block,unblock,approve,deny', ARGUMENTS.action) ) {
					LOCAL['config']['params']['action'] = ARGUMENTS.action;
				} else {
					return pkgStruct('', 0, 'Action must be one of the following: follow, unfollow, block, unblock, approve or deny.');
				}
			}
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 MEDIA METHODS ###############################################
		################################################################
	--->
	<cffunction name="media" description="Get information about a media object" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="media_id" type="string" required="true" hint="ID of the object to be retrieved.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/' & ARGUMENTS.media_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="mediaSearch" description="Search for media in a given area" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="lat" type="string" required="true" hint="Latitude of the center search coordinate.">
		<cfargument name="lng" type="string" required="true" hint="Longitude of the center search coordinate.">
		<cfargument name="max_timestamp" type="string" required="false" hint="A unix timestamp. All media returned will be taken earlier than this timestamp.">
		<cfargument name="min_timestamp" type="string" required="false" hint="A unix timestamp. All media returned will be taken later than this timestamp.">
		<cfargument name="distance" type="numeric" required="false" hint="Default is 1km.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['lat'] = ARGUMENTS.lat;
			LOCAL['config']['params']['lng'] = ARGUMENTS.lng;
			if ( StructKeyExists(ARGUMENTS,'max_timestamp') ) LOCAL['config']['params']['max_timestamp'] = ARGUMENTS.max_timestamp;
			if ( StructKeyExists(ARGUMENTS,'min_timestamp') ) LOCAL['config']['params']['min_timestamp'] = ARGUMENTS.min_timestamp;
			if ( StructKeyExists(ARGUMENTS,'distance') ) LOCAL['config']['params']['distance'] = ARGUMENTS.distance;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="mediaPopular" description="Get a list of what media is most popular at the moment" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/popular';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 COMMENT METHODS ###############################################
		################################################################
	--->
	<cffunction name="comments" description="Get a full list of comments on a media" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="media_id" type="string" required="true" hint="ID of the object to be retrieved.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/' & ARGUMENTS.media_id & '/comments';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="commentAdd" description="Create a comment on a media" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="media_id" type="string" required="true" hint="ID of the object to be retrieved.">
		<cfargument name="text" type="string" required="true" hint="Text to post as a comment on the media.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/' & ARGUMENTS.media_id & '/comments';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['text'] = ARGUMENTS.text;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="commentDelete" description="Create a comment on a media" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="media_id" type="string" required="true" hint="ID of the object to be retrieved.">
		<cfargument name="comment_id" type="string" required="true" hint="The id of the comment to be deleted.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'DELETE';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/' & ARGUMENTS.media_id & '/comments/' & ARGUMENTS.comment_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 LIKES METHODS ###############################################
		################################################################
	--->
	<cffunction name="like" description="Get, add, or delete a likes from media" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="media_id" type="string" required="true" hint="ID of the object to be retrieved.">
		<cfargument name="action" type="string" default="view" required="false" hint="Add a like to this media. One of add,delete">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			if ( StructKeyExists(ARGUMENTS,'action') AND ListFindNoCase('add,delete',ARGUMENTS.action) ) {
				switch(ARGUMENTS.action) {
					case 'add':
						LOCAL['config']['method'] = 'POST';
						break;
					case 'delete':
						LOCAL['config']['method'] = 'DELETE';
						break;
				}
			} else {
				LOCAL['config']['method'] = 'GET';
			}
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/media/' & ARGUMENTS.media_id & '/likes';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 TAG METHODS ###############################################
		################################################################
	--->
	<cffunction name="tag" description="Get information about a tag object" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="tag" type="string" required="true" hint="ID of the object to be retrieved.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tags/' & ARGUMENTS.tag;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="tagRecent" description="Gets a list of recently tagged media" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="tag" type="string" required="true" hint="ID of the object to be retrieved.">
		<!---
		<cfargument name="max_tag_id" type="string" required="false" hint="Return media after this max_tag_id.">
		<cfargument name="min_tag_id" type="string" required="false" hint="Return media before this min_tag_id.">
		--->

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tags/' & ARGUMENTS.tag & '/media/recent';

			// variables required by this method
			LOCAL['config']['params'] = {};
			//if ( StructKeyExists(ARGUMENTS,'max_tag_id') ) LOCAL['config']['params']['max_tag_id'] = ARGUMENTS.max_tag_id;
			//if ( StructKeyExists(ARGUMENTS,'min_tag_id') ) LOCAL['config']['params']['min_tag_id'] = ARGUMENTS.min_tag_id;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="tagSearch" description="Search for tags by name - results are ordered first as an exact match, then by popularity" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="q" type="string" required="true" hint="valid tag name without a leading ##. (eg. snow, nofilter)">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tags/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['q'] = ARGUMENTS.q;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 LOCATION METHODS ###############################################
		################################################################
	--->
	<cffunction name="location" description="Get information about a location" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="location_id" type="string" required="true" hint="ID of the object to be retrieved.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/locations/' & ARGUMENTS.location_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="locationRecent" description="Get a list of recent media objects from a given location" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="location_id" type="string" required="true" hint="ID of the object to be retrieved.">
		<cfargument name="max_id" type="string" required="false" hint="Return media after this max_id.">
		<cfargument name="min_id" type="string" required="false" hint="Return media before this max_id.">
		<cfargument name="min_timestamp" type="string" required="false" hint="Return media after this UNIX timestamp.">
		<cfargument name="max_timestamp" type="string" required="false" hint="Return media before this UNIX timestamp.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/locations/' & ARGUMENTS.location_id & '/media/recent';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'max_id') ) LOCAL['config']['params']['max_id'] = ARGUMENTS.max_id;
			if ( StructKeyExists(ARGUMENTS,'min_id') ) LOCAL['config']['params']['min_id'] = ARGUMENTS.min_id;
			if ( StructKeyExists(ARGUMENTS,'min_timestamp') ) LOCAL['config']['params']['min_timestamp'] = ARGUMENTS.min_timestamp;
			if ( StructKeyExists(ARGUMENTS,'max_timestamp') ) LOCAL['config']['params']['max_timestamp'] = ARGUMENTS.max_timestamp;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="locationSearch" description="Search for a location by geographic coordinate" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="json">
		<cfargument name="lat" type="string" required="false" hint="Latitude of the center search coordinate.">
		<cfargument name="lng" type="string" required="false" hint="Longitude of the center search coordinate.">
		<cfargument name="foursquare_v2_id" type="string" required="false" hint="Returns a location mapped off of a foursquare v2 api location id. If used, you are not required to use lat and lng">
		<cfargument name="distance" type="numeric" required="false" hint="Default is 1000m (distance=1000), max distance is 5000">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/locations/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'lat') ) LOCAL['config']['params']['lat'] = ARGUMENTS.lat;
			if ( StructKeyExists(ARGUMENTS,'lng') ) LOCAL['config']['params']['lng'] = ARGUMENTS.lng;
			if ( StructKeyExists(ARGUMENTS,'foursquare_v2_id') ) LOCAL['config']['params']['foursquare_v2_id'] = ARGUMENTS.foursquare_v2_id;
			if ( StructKeyExists(ARGUMENTS,'distance') ) LOCAL['config']['params']['distance'] = ARGUMENTS.distance;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

</cfcomponent>




















