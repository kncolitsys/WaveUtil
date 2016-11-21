<!---
	Name: WaveUtil.cfc
	Purpose: Encapsulation of Adobe Wave functionality without configuring any authentication
	Notes: Dealing with just the broadcast functions at the moment
	Version: 0.1 (beta)
--->
<!--- Example of function calling this CFC is at the end of the file --->

<cfcomponent name="WaveUtil" hint="Encapsulation of Adobe Wave functionality without configuring any authentication">

	<!--- INITIALISATION --->
		<cffunction name="init" access="public" output="false" returntype="WaveUtil" hint="Initialise and get the fixed values configured">
			<!--- Configure URLs so that we can change them easily when the beta is over! --->
			<cfset variables.url = {
					apiToken="https://id-wave.adobe.com/identity/1.0/auth/apitoken.xml",
					oauth="https://id-wave.adobe.com/identity/1.0/oauth/requesttoken",
					notification="https://p000-wave.adobe.com/notificationgateway/1.0/notification"
			}>

			<cfreturn this>
		</cffunction>

		<cffunction name="configure" access="public" output="false" returntype="void" hint="Read in the config and set into the variables">
			<cfargument name="config" type="xml" required="true">

			<cfset var local = {}>

			<cfset variables.auth = {
					username=arguments.config.config.auth.xmlAttributes.username,
					password=arguments.config.config.auth.xmlAttributes.password
			}>

			<cfset local.token = retrieveApiToken(variables.auth.username, variables.auth.password)>
			<cfset setApiToken(local.token)>

			<!--- Build out the structure of topics for your feed so you don't have to remember the URI's --->
			<cfset variables.topics = {}>
			<cfloop from="1" to="#ArrayLen(arguments.config.config.topic)#" index="local.i">
				<cfset variables.topics[arguments.config.config.topic[local.i].xmlAttributes.name]
						= arguments.config.config.topic[local.i].xmlAttributes.udi>
			</cfloop>
		</cffunction>

	<!--- API calls --->
		<cffunction name="retrieveApiToken" access="private" output="false" returntype="string" hint="used to retrieve an API key from adobe">
			<cfargument name="userName" type="string" required="true" hint="Your Adobe Publisher Portal Username">
			<cfargument name="password" type="string" required="true" hint="Your Adobe Publisher Portal Password">

			<cfset var local = {}>
			<cfset local.token = "">

			<!--- real --->
			<cfhttp URL="#variables.url.apiToken#" method="POST" result="local.APIKeyCall">
				<cfhttpparam type="url" name="username" value="#variables.auth.username#">
				<cfhttpparam type="url" name="password" value="#variables.auth.password#">
			</cfhttp>

			<!--- If authentication passes, return the API key, otherwise return an error message --->
			<cfif local.APIKeyCall.responseheader.status_code EQ "200">
				<cfset local.token = trim(xmlParse(local.APIKeyCall.filecontent).apitokenResponse.apiToken.XmlText)>
			<cfelse>
				<cfset local.token = "authentication failure for api key">
			</cfif>

			<cfreturn local.token>
		</cffunction>

		<cffunction name="sendNotification" access="public" output="true" returntype="boolean" hint="sends a notification to the Adove Wave API">
			<cfargument name="topicName" type="string" required="true" hint="This name will relate to the key in the structure created in the init">
			<cfargument name="message" type="string" required="true" hint="The message that will be published">
			<cfargument name="link" type="string" default="" hint="If you wish the user to go to a specific link when the notification is clicked, pass that in here">

			<cfset var local = {}>
			<cfset local.success = false>
			<cfset local.fieldType = "formfield">

			<!--- make the http request to the https url --->
			<cfhttp method="post" url="#variables.url.notification#" result="local.APINotificationCall">
				<cfhttpparam type="#local.fieldtype#" name="X-apitoken" value="#urlEncodedFormat(getApiToken())#">
				<cfhttpparam type="#local.fieldtype#" name="topic" value="#getTopicByName(arguments.topicName)#">
				<cfhttpparam type="#local.fieldtype#" name="message" value="#arguments.message#">
	 			<cfif arguments.link NEQ "">
					<cfhttpparam type="#local.fieldtype#" name="link" value="#arguments.link#">
				</cfif>
			</cfhttp>

			<cfif local.APINotificationCall.responseheader.status_code EQ "204">
				<!--- If we receive a code of 204, that means the notification went through --->
				<cfset local.success = true>

			<cfelseif local.APINotificationCall.responseheader.status_code EQ "401" OR local.APINotificationCall.responseheader.status_code EQ "403">
				<!--- If we receive a response of 401 or 403, that likely means the api key failed, so we need to get a new api key and try again --->
				<!--- LOOP DANGER --->
				<cfparam name="request.wave.counter" default="0">
				<cfset request.wave.counter++>
				<cfif request.wave.counter lt 10>
					<cfset setApiToken(retrieveApiToken(variables.username, variables.password))>
					<cfset local.success = sendNotification(arguments.topicName, arguments.message, arguments.link, arguments.accessToken, arguments.imageURL)>
				<cfelse>
					<cfset local.success = false>
				</cfif>

			<cfelse>
				<!--- if something else happened entirely, we just return false for a success --->
				<cfset local.success = false>
			</cfif>

			<cfreturn local.success>
		</cffunction>

	<!--- UTILITIES --->
		<cffunction name="getTopics" access="private" output="false" returntype="struct" hint="returns the structure of categories you have setup">
			<!--- Reutrn the list of topics you have created --->
			<cfreturn variables.topics>
		</cffunction>

		<cffunction name="getTopicByName" access="private" output="false" returntype="string">
			<cfargument name="topicName" type="string" required="true">
			<cfset var local = {topics = getTopics()}>
			<cfreturn local.topics[arguments.topicName]>
		</cffunction>

		<cffunction name="setApiToken" access="private" output="false" returntype="void">
			<cfargument name="apiToken" type="string" required="true">

			<cfset variables.auth.apiToken = arguments.apiToken>
		</cffunction>

		<cffunction name="getApiToken" access="private" output="false" returntype="string">
			<cfif NOT Len(variables.auth.apiToken)>
				<cfset setApiToken(retrieveApiToken())>
			</cfif>
			<cfreturn variables.auth.apiToken>
		</cffunction>

</cfcomponent>

<!--- Example of function calling this CFC
	<cffunction name="testWave" access="public" returntype="struct">
		<!--- The Result object contains success(boolean) and output(string). Change to what you need --->
		<cfset var local = {result=getApplication().getResult()}>

		<!--- the Scope object in factory combines the URL and FORM variables. Change this to suit your needs --->
		<cfset local.scope = getFactory().get("scope").get()>

		<!--- Configure your Wave Publisher account here --->
		<cfxml variable="local.config">
			<config>
				<auth username="ADOBE_USERNAME" password="ADOBE_PASSWORD"/>
				<topic name="Announcement" udi="TOPIC_UDI_1"/>
				<topic name="Warnings" udi="TOPIC_UDI_2"/>
			</config>
		</cfxml>

		<!--- No need to change anything below here --->
		<cfsavecontent variable="local.result.output">
			<cftry>
				<cfif NOT StructKeyExists(local.scope, "submit")>
					<cfoutput>
						<form action="#local.scope.script_name#" method="post">
							<h3>Topic</h3>
							<select name="topicName">
								<cfloop from="1" to="#ArrayLen(local.config.config.topic)#" index="local.i">
									<option value="#local.config.config.topic[local.i].xmlAttributes.name#">#local.config.config.topic[local.i].xmlAttributes.name#</option>
								</cfloop>
							</select>
							<h3>Message</h3>
							<textarea cols="30" rows="10" name="message"></textarea>
							<h3>Link</h3>
							<input type="text" name="link">
							<p><input type="submit" value="go" name="submit"></p>
						</form>
					</cfoutput>

				<cfelse>
					<cfset local.wave = createObject("component", "glacier.com.util.waveUtil").init()>
					<cfset local.wave.configure(local.config)>

					<cfset local.message =
							local.scope.message
							& " [" & DateFormat(now(), "d-mm-yy") & " " & TimeFormat(now(), "HH:mm") & "]"
					>

					<cfset local.wave.sendNotification(
							topicName=local.scope.topicName,
							message=local.message,
							link=local.scope.link
					)>
				</cfif>

				<cfcatch type="any">
					<cfdump var="#cfcatch#">
				</cfcatch>
			</cftry>
		</cfsavecontent>

		<cfreturn local.result>
	</cffunction>

--->
