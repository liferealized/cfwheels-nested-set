<cfset application.wheels.modelPath = application.wheels.rootPath & application.wheels.pluginPath & "/nestedset/_assets/models">
<cfset application.wheels.modelComponentPath = "wheelsMapping.tests._assets.models">
<cfset application.wheels.dataSourceName = "nestedsetdb" />
<cfset application.wheels.dataSourceUserName = "" />
<cfset application.wheels.dataSourcePassword = "" />
<!--- unload all plugins before running core tests --->
<cfset application.wheels.plugins = {}>
<cfset application.wheels.mixins = {}>