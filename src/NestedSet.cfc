<cfcomponent displayname="Nested Sets for CF Wheels">

	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
	Title:		Nested Sets Plugin for CF Wheels (http://cfwheels.org)
	
	Source:		http://github.com/liferealized/cfwheels-nested-set
	
	Authors:	James Gibson 	(me@iamjamesgibson.com)
				Andy Bellenie 	(andybellenie@gmail.com)

	Notes:		Ported from Awesome Nested Sets for Rails
				http://github.com/collectiveidea/awesome_nested_set

	Usage:		Use hasNestedSet() in your model init to setup for the methods below
				defaults
					- idColumn = '' (defaults to the primary key during validation)
					- parentColumn = 'parentId'
					- leftColumn = 'lft'
					- rightColumn = 'rgt'
					- scope = ''
					- instantiateOnDelete = false
					- idsAreNullable = true

	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="init" access="public" output="false" returntype="any">
		<cfset this.version = 1.0 />
		<cfreturn this />
	</cffunction>
		
		
	<cffunction name="actsAsNestedSet" returntype="void" access="public" output="false" mixin="model">
		<cfargument name="idColumn" type="string" default="">
		<cfargument name="parentColumn" type="string" default="parentId">
		<cfargument name="leftColumn" type="string" default="lft">
		<cfargument name="rightColumn" type="string" default="rgt">
		<cfargument name="scope" type="string" default="">
		<cfargument name="instantiateOnDelete" type="boolean" default="false">
		<cfargument name="idsAreNullable" type="boolean" default="true">
		<cfscript>
			// add the nested set configuration into the model
			variables.wheels.class.nestedSet = Duplicate(arguments);
			variables.wheels.class.nestedSet.scope = Replace(variables.wheels.class.nestedSet.scope,", ",",","all");
			variables.wheels.class.nestedSet.isValidated = false;
			// set callbacks
			beforeCreate(methods="$setDefaultLeftAndRight");
			afterSave(methods="$moveToNewParent");
			beforeDelete(methods="$deleteDescendants");
			// add in a calculated property for the leaf value
			property(name="leaf", sql="#arguments.rightColumn# - #arguments.leftColumn#");
			// allow for the two new types of callbacks
			variables.wheels.class.callbacks.beforeMove = ArrayNew(1);
			variables.wheels.class.callbacks.afterMove = ArrayNew(1);
		</cfscript>
	</cffunction>

	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		private accessors for our nested set values
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="$getIdColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.idColumn />
	</cffunction>

	<cffunction name="$getIdType" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.properties[variables.wheels.class.nestedSet.idColumn].type />
	</cffunction>

	<cffunction name="$getParentColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.parentColumn />
	</cffunction>
	
	<cffunction name="$getLeftColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.leftColumn />
	</cffunction>
	
	<cffunction name="$getRightColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.rightColumn />
	</cffunction>
	
	<cffunction name="$getScope" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.scope />
	</cffunction>
	
	<cffunction name="$getInstantiateOnDelete" returntype="boolean" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.instantiateOnDelete />
	</cffunction>

	<cffunction name="$idsAreNullable" returntype="boolean" access="public" output="false" mixin="model">
		<cfset $validateNestedSet()>
		<cfreturn variables.wheels.class.nestedSet.idsAreNullable />
	</cffunction>
	


	<!---
		plugin validation
	--->

	<cffunction name="$validateNestedSet" returntype="void" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {};

			// check hasNestedSet() has been run
			if (not StructKeyExists(variables.wheels.class,"nestedSet"))	
				$throw(type="Wheels.Plugins.NestedSet.SetupNotComplete",message="You must call hasNestedSet() from your model's init() before you can use NestedSet methods.");
			
			// skip validation if it has already run
			if (not variables.wheels.class.nestedSet.isValidated) {
				// check for custom id column, otherwise use the primary key from the model
				if (not Len(variables.wheels.class.nestedSet.idColumn))
					variables.wheels.class.nestedSet.idColumn = primaryKey();
				// check id types match
				if (CompareNoCase(variables.wheels.class.properties[variables.wheels.class.nestedset.idColumn].type,variables.wheels.class.properties[variables.wheels.class.nestedset.parentColumn].type) neq 0)	
					$throw(type="Wheels.Plugins.NestedSet.KeyTypeMismatch",message="The cf_sql_type of the idColumn and parentColumn must be identical.");
				// check scope fields are present in the object
				for (loc.i=1; loc.i lte ListLen(variables.wheels.class.nestedSet.scope); loc.i++) {
					// if (not StructKeyExists(this,ListGetAt(variables.wheels.class.nestedSet.scope,loc.i)))
					if (not StructKeyExists(variables.wheels.class.properties,ListGetAt(variables.wheels.class.nestedSet.scope,loc.i)))
						$throw(type="Wheels.Plugins.NestedSet.ScopePropertyMissing",message="The property '#ListGetAt(variables.wheels.class.nestedSet.scope,loc.i)#' required in the scope argument is not present in the model.");
				}
				variables.wheels.class.nestedSet.isValidated = true;
			}
		</cfscript>
	</cffunction>
	
	
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		id validation methods
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	

	<cffunction name="$propertyIsInteger" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="property" type="string" required="true">
		<cfreturn ListFindNoCase("cf_sql_integer,cf_sql_bigint,cf_sql_tinyint,cf_sql_smallint",variables.wheels.class.properties[arguments.property].type)>
	</cffunction>


	<cffunction name="$idIsValid" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="id" type="string" required="true">
		<cfif $propertyIsInteger($getIdColumn())>
			<cfreturn IsNumeric(arguments.id)>
		</cfif>
		<cfreturn not IsBoolean(arguments.id) and Len(arguments.id) gt 0>
	</cffunction>
	
	
	<cffunction name="$formatIdForQuery" returntype="string" access="public" output="false" mixin="model">
		<cfargument name="id" type="string" required="true">
		<cfargument name="match" type="boolean" default="true">
		<cfset arguments.id = Trim(arguments.id)>
		<cfif $idsAreNullable() and arguments.id eq "">
			<cfif arguments.match>
				<cfreturn "IS NULL">
			</cfif>
			<cfreturn "IS NOT NULL">
		</cfif>
		<cfif $propertyIsInteger($getIdColumn())>
			<cfif arguments.match>
				<cfreturn "= #arguments.id#">
			</cfif>
			<cfreturn "!= #arguments.id#">
		</cfif>
		<cfif arguments.match>
			<cfreturn "= '#arguments.id#'">
		</cfif>
		<cfreturn "!= '#arguments.id#'">
	</cffunction>



	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		add in new callback types of beforeMove and afterMove for nested sets
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="beforeMove" returntype="void" access="public" output="false" mixin="model">
		<cfargument name="methods" type="string" required="false" default="" />
		<cfset $registerCallback(type="beforeMove", argumentCollection=arguments) />
	</cffunction>	
	
	
	<cffunction name="afterMove" returntype="void" access="public" output="false" mixin="model">
		<cfargument name="methods" type="string" required="false" default="" />
		<cfset $registerCallback(type="afterMove", argumentCollection=arguments) />
	</cffunction>	



	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		class level methods
		e.g. model("user").allRoots();
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="firstRoot" returntype="any" access="public" output="false" hint="I return the first root object.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $appendWhereClause(arguments.where,"#$getParentColumn()# IS NULL")>
		<cfreturn findOne(argumentcollection=arguments) />
	</cffunction>
	

	<cffunction name="allRoots" returntype="any" access="public" output="false" hint="I return all root objects.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $appendWhereClause(arguments.where,"#$getParentColumn()# IS NULL")>
		<cfreturn findAll(argumentcollection=arguments) />
	</cffunction>
	
	
	<cffunction name="isTreeValid" returntype="boolean" access="public" output="false">
		<cfreturn (leftAndRightIsValid() and noDuplicatesForColumns() and allRootsValid())>
	</cffunction>
	
	
	<cffunction name="leftAndRightIsValid" returntype="boolean" access="public" output="false">
		<cfset var loc = {}>
		
		<cfquery name="loc.query" attributeCollection="#variables.wheels.class.connection#">
			SELECT 		COUNT(*) AS leftRightCount
			FROM 		#tableName()# AS nodes
			LEFT JOIN 	#tableName()# AS parent ON nodes.#$getParentColumn()# = parent.#$getIdColumn()#
			WHERE 		(
						nodes.#$getLeftColumn()# IS NULL 
						OR nodes.#$getRightColumn()# IS NULL 
						OR nodes.#$getLeftColumn()# >= nodes.#$getRightColumn()# 
						OR (
							nodes.#$getParentColumn()# IS NOT NULL 
							AND (
								nodes.#$getLeftColumn()# <= parent.#$getLeftColumn()# 
								OR nodes.#$getRightColumn()# >= parent.#$getRightColumn()#
								)
							)
						)
		</cfquery>
		
		<cfreturn (loc.query.leftRightCount eq 0) />
	</cffunction>
	
	
	<cffunction name="noDuplicatesForColumns">
		<cfscript>
			var loc = {
				  select = $getScope()
				, columns = ListAppend($getLeftColumn(), $getRightColumn())
				, queryArgs = StructCopy(variables.wheels.class.connection)
				, queries = {}
				, returnValue = true
			};
			
			loc.iEnd = ListLen(loc.columns);
		</cfscript>
		
		<cfloop index="loc.i" from="1" to="#loc.iEnd#">
			<cfset loc.column = ListGetAt(loc.columns, loc.i) />
			<cfset loc.queryArgs.name = "loc.queries.#loc.column#" />
			<cfquery attributeCollection="#loc.queryArgs#">
				SELECT #ListAppend(loc.select, loc.column)#, COUNT(#loc.column#)
				FROM #tableName()#
				GROUP BY #ListAppend(loc.select, loc.column)#
				HAVING COUNT(#loc.column#) > 1
			</cfquery>
		</cfloop>
		
		<cfscript>
			for (loc.item in loc.queries)
				if (loc.queries[loc.item].RecordCount gt 0) {
					loc.returnValue = false;
					break;
				}
		</cfscript>
		<cfreturn loc.returnValue />
	</cffunction>
	
	
	<cffunction name="allRootsValid">
		<cfreturn this.eachRootValid(this.allRoots(argumentCollection=arguments)) />
	</cffunction>
	
	
	<cffunction name="eachRootValid" returntype="boolean" access="public" output="false">
		<cfargument name="roots" type="query" required="true" />
		<cfscript>
			var loc = {
				  lft = 0
				, rgt = 0
				, iEnd = arguments.roots.RecordCount
				, valid = true
			};
			
			for (loc.i=1; loc.i lte loc.iEnd; loc.i++) {
				if (arguments.roots[$getLeftColumn()][loc.i] gt loc.lft and arguments.roots[$getRightColumn()][loc.i] gt loc.rgt) {
					loc.lft = arguments.roots[$getLeftColumn()][loc.i];
					loc.rgt = arguments.roots[$getRightColumn()][loc.i];
				} else {
					loc.valid = false;
					break;
				}
			}
		</cfscript>
		<cfreturn loc.valid />
	</cffunction>
	
	
	<cffunction name="rebuild">
		<cfthrow type="Wheels.Plugins.NestedSet.NotImplemented" message="This method has not been implemented yet." />
	</cffunction>
	
	
	
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		instance level methods
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="isRoot" returntype="boolean" access="public" output="false" hint="I return true if the current node is a root node.">
		<cfreturn not $idIsValid(this[$getParentColumn()]) />
	</cffunction>
	

	<cffunction name="isChild" returntype="boolean" access="public" output="false" hint="I return true if the current node is a child node.">
		<cfreturn $idIsValid(this[$getParentColumn()]) />
	</cffunction>
	
	
	<cffunction name="isLeaf" returntype="boolean" access="public" output="false" hint="I return true if the current node is a leaf node (i.e. has no children).">
		<cfreturn !isNew() and (this[$getRightColumn()] - this[$getLeftColumn()] eq 1) />
	</cffunction>
	
	
	<cffunction name="root" returntype="any" access="public" output="false" hint="I return the root object for the current node's branch.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# <= #this[$getLeftColumn()]# AND #$getRightColumn()# >= #this[$getRightColumn()]# AND #$getParentColumn()# IS NULL")>
		<cfreturn findOne(argumentcollection=arguments) />
	</cffunction>
	
	
	<cffunction name="selfAndAncestors" returntype="any" access="public" output="false" hint="I return the current node and all of its parents down to the root.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# DESC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# <= #this[$getLeftColumn()]# AND #$getRightColumn()# >= #this[$getRightColumn()]#")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	
	<cffunction name="ancestors" returntype="any" access="public" output="false" hint="I return all of the current nodes's parents down to the root.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# DESC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# < #this[$getLeftColumn()]# AND #$getRightColumn()# > #this[$getRightColumn()]#")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	
	<cffunction name="selfAndSiblings" returntype="any" access="public" output="false" hint="I return the current node and its siblings.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getParentColumn()# #$formatIdForQuery(this[$getParentColumn()])#")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	
	<cffunction name="siblings" returntype="any" access="public" output="false" hint="I return the current node's siblings.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getParentColumn()# #$formatIdForQuery(this[$getParentColumn()])# AND #$getIdColumn()# != 'e7ebe656-0f26-a649-beda-67036318c768'")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	
	<cffunction name="leaves" returntype="any" access="public" output="false" hint="I return all children of the current node that do not have children themselves.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]# AND leaf = 1")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>  
	
	
	<cffunction name="selfAndDescendants" returntype="any" access="public" output="false" hint="I return the current node and its descendants.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# >= #this[$getLeftColumn()]# AND #$getRightColumn()# <= #this[$getRightColumn()]#")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	
	<cffunction name="descendants" returntype="any" access="public" output="false" hint="I return the current node's descendants.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]#")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="isDescendantOf" returntype="boolean" access="public" output="false" hint="I return true if the current node is a descendant of the supplied node.">
		<cfargument name="target" type="any" required="true" hint="I am either the id of a node or the node itself.">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target) and arguments.target[$getLeftColumn()] lt this[$getLeftColumn()] and this[$getLeftColumn()] lt arguments.target[$getRightColumn()] and isSameScope(arguments.target)>
			<cfreturn true>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	
	<cffunction name="isAncestorOf" returntype="boolean" access="public" output="false" hint="I return true if the current node is an ancestor of the supplied node.">
		<cfargument name="target" type="any" required="true" hint="I am either the id of a node or the node itself.">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target) and this[$getLeftColumn()] lt arguments.target[$getLeftColumn()] and arguments.target[$getLeftColumn()] lt this[$getRightColumn()] and isSameScope(arguments.target)>
			<cfreturn true>
		</cfif>
		<cfreturn false>
	</cffunction>


	<cffunction name="level" returntype="numeric" access="public" output="false" hint="I return the current level of this node as expressed from the root.">
		<cfif not IsNumeric(this[$getParentColumn()])>
			<cfreturn 1>
		</cfif>
		<cfreturn selfAndAncestors(returnAs="query").RecordCount>
	</cffunction>


	<cffunction name="selfAndChildren" returntype="any" access="public" output="false" hint="I return the current node and its immediate children.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# >= #this[$getLeftColumn()]# AND #$getRightColumn()# <= #this[$getRightColumn()]# AND (#$getParentColumn()# #$formatIdForQuery(this[$getIdColumn()])# OR #$getIdColumn()# #$formatIdForQuery(this[$getIdColumn()])#)")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>


	<cffunction name="children" returntype="any" access="public" output="false" hint="I return the current node's immediate children.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]# AND #$getParentColumn()# #$formatIdForQuery(this[$getIdColumn()])#")>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>


	<cffunction name="parent" returntype="any" access="public" output="false" hint="I return the parent of the current node.">
		<cfreturn findOne(where="$getIdColumn=#this[$getParentColumn()]#")>
	</cffunction>


	<cffunction name="isSameScope" returntype="boolean" access="public" output="false" hint="I return true if the supplied target is of the same scope as the current node.">
		<cfargument name="target" type="any" required="true" hint="I am either the id of a node or the node itself.">
		<cfscript>
			var loc = {};
			// check target object exists
			arguments.target = $getObject(arguments.target);
			if (not IsObject(arguments.target))
				return false;

			// no scoping defined, true by default
			if (not Len($getScope()))
				return true;
				
			for (loc.i=1; loc.i lte ListLen($getScope()); loc.i++)
				if (this[ListGetAt($getScope(), loc.i)] != arguments.target[ListGetAt($getScope(), loc.i)])
					return false;
		</cfscript>
		<cfreturn true />
	</cffunction>
	

	<cffunction name="leftSibling" returntype="any" access="public" output="false" hint="I return the nearest sibling to the left of the current node.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getRightColumn()# = #this[$getLeftColumn()] - 1# AND #$getParentColumn()# #$formatIdForQuery(this[$getParentColumn()])#")>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>


	<cffunction name="rightSibling" returntype="any" access="public" output="false" hint="I return the nearest sibling to the right of the current node.">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="#$getLeftColumn()# ASC">
		<cfset arguments.where = $createScopedWhere(arguments.where,"#$getLeftColumn()# = #this[$getRightColumn()] + 1# AND #$getParentColumn()# #$formatIdForQuery(this[$getParentColumn()])#")>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>

	
	<cffunction name="moveLeft" returntype="boolean" access="public" output="false" mixin="model" hint="I exchange position with the nearest sibling to the left of the current node.">
		<cfreturn moveToLeftOf(leftSibling())>
	</cffunction>

	
	<cffunction name="moveRight" returntype="boolean" access="public" output="false" mixin="model" hint="I exchange position with the nearest sibling to the right of the current node.">
		<cfreturn moveToRightOf(rightSibling())>
	</cffunction>

	<cffunction name="moveToLeftOf" returntype="boolean" access="public" output="false" mixin="model" hint="I move the current node to the left of the target node.">
		<cfargument name="target" type="any" required="true" hint="I am either the id of a node or the node itself.">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target)>
			<cfreturn $moveTo(arguments.target,"left")>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	<cffunction name="moveToRightOf" returntype="boolean" access="public" output="false" mixin="model" hint="I move the current node to the right of the target node.">
		<cfargument name="target" type="any" required="true" hint="I am either the id of a node or the node itself.">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target)>
			<cfreturn $moveTo(arguments.target, "right")>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	<cffunction name="moveToChildOf" returntype="boolean" access="public" output="false" mixin="model" hint="I move the current node underneath the target node.">
		<cfargument name="target" type="any" required="true" hint="I am either the id of a node or the node itself.">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target)>
			<cfreturn $moveTo(arguments.target, "child")>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	<cffunction name="moveToRoot" returntype="boolean" access="public" output="false" mixin="model" hint="I move the current node to the first root position.">
		<cfreturn $moveTo("", "root") />
	</cffunction>
	
	<cffunction name="isMovePossible" returntype="boolean" access="public" output="false" mixin="model" hint="I check to see that the requested move is possible.">
		<cfargument name="target" type="component" required="true" />
		<cfscript>
			if (this.key() == target.key() or not isSameScope(arguments.target))
				return false;
			if (((this[$getLeftColumn()] lte target[$getLeftColumn()] and this[$getRightColumn()] gte arguments.target[$getLeftColumn()]) 
				or (this[$getLeftColumn()] lte target[$getRightColumn()] and this[$getRightColumn()] gte arguments.target[$getRightColumn()])))
				return false;
			return true;
		</cfscript>
	</cffunction>
	
	<cffunction name="toText" returntype="string" access="public" output="false" mixin="model">
		<cfthrow type="Wheels.Plugins.NestedSet.NotImplemented" message="This method has not been implemented yet." />
	</cffunction>
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		private methods
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>
	
	<cffunction name="$moveToNewParent" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			var parent = $getObject(this[$getParentColumn()]);
			if (IsObject(parent))
				if (not isSameScope(parent)) {			
					$throw(type="Wheels.Plugins.NestedSet.ScopeMismatch",message="The supplied parent is not within the same scope as the item you are trying to insert.");
				} else {
					moveToChildOf(parent);
				}
			// return true even if we did nothing as the node has already been inserted at root level
			return true;
		</cfscript>
	</cffunction>
	
	
	<cffunction name="$setDefaultLeftAndRight" returntype="void" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {
				  maxRight = this.maximum(property=$getRightColumn())
				, leftColumn = loc.maxRight + 1
				, rightColumn = loc.maxRight + 2
			};
			
			this[$getLeftColumn()] = loc.leftColumn;
			this[$getRightColumn()] = loc.rightColumn;
		</cfscript>
	</cffunction>
	
	<!---
		removes all descendants of itself before being deleted
		if you would like callbacks to run for each object deleted, simply
		pass the argument instanciateOnDelete=true into hasNestedSet() 
	--->
	<cffunction name="$deleteDescendants" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {};	
			
			// make sure this method can only run on the original object
			if (StructKeyExists(request, "deleteDescendantsCalled"))
				return true;
			
			if (not IsNumeric(this[$getRightColumn()]) or not IsNumeric(this[$getLeftColumn()]))
				return true;

			arguments.where = $createScopedWhere(where="", append="#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]#");
			request.deleteDescendantsCalled = true;
			deleteAll(argumentCollection=arguments, instantiate=$getInstantiateOnDelete());
			loc.diff = this[$getRightColumn()] - this[$getLeftColumn()] + 1;
		</cfscript>
		
		<cfquery datasource="#variables.wheels.class.connection.datasource#" name="loc.query">
			UPDATE 	#tableName()#
			SET 	#$getLeftColumn()# = #$getLeftColumn()# - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.diff#">
			WHERE	#$getLeftColumn()# > <cfqueryparam cfsqltype="cf_sql_integer" value="#this[$getRightColumn()]#">
			<cfif ListLen($getScope()) gt 0>
				<cfloop list="#$getScope()#" index="loc.property">
				AND		#loc.property# = <cfqueryparam cfsqltype="#variables.wheels.class.properties[loc.property].type#" value="#this[loc.property]#">
				</cfloop>
			</cfif>
			;
			UPDATE 	#tableName()# 
			SET 	#$getRightColumn()# = #$getRightColumn()# - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.diff#">
			WHERE	#$getRightColumn()# > <cfqueryparam cfsqltype="cf_sql_integer" value="#this[$getRightColumn()]#">
			<cfif ListLen($getScope()) gt 0>
				<cfloop list="#$getScope()#" index="loc.property">
				AND		#loc.property# = <cfqueryparam cfsqltype="#variables.wheels.class.properties[loc.property].type#" value="#this[loc.property]#">
				</cfloop>
			</cfif>
		</cfquery>
		
		<cfreturn true />
	</cffunction>
	
	<!---
		core private method used to move items around in the tree
		update should not be scoped since the entire table is one big tree
	--->
	<cffunction name="$moveTo" returntype="any" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true" />
		<cfargument name="position" type="string" required="true" hint="may be one of 'child, left, right, root'" />
		<cfscript>
			var loc = {
				  queryArgs = variables.wheels.class.connection
			};
		</cfscript>
		
		<cftransaction action="begin">
			<cfscript>
				
				if (isNew())
					$throw(type="Wheels.Plugins.NestedSet.MoveNotAllowed", message="You cannot move a new node!");
					
				if (!$callback("beforeMove"))
					return false;
				
				// reload this object so we have the freshest data
				this.reload();
				
				// make sure we can do the move
				if (arguments.position != "root" and !isMovePossible(arguments.target))
					$throw(type="Wheels.Plugins.NestedSet.MoveNotAllowed", message="Impossible move, target node cannot be inside moved tree.");
				
				switch (arguments.position) {
				
					case "child": { loc.bound = arguments.target[$getRightColumn()];     break; }
					case "left":  { loc.bound = arguments.target[$getLeftColumn()];      break; }
					case "right": { loc.bound = arguments.target[$getRightColumn()] + 1; break; }
					case "root":  { loc.bound = 1; break; }
					default: {
						$throw(type="Wheels.Plugins.NestedSet.IncorrectArgumentValue", message="Position should be 'child', 'left', 'right' or 'root' ('#arguments.position#' received).");
					}
				}
				
				if (loc.bound gt this[$getRightColumn()]) {
					loc.bound--;
					loc.otherBound = this[$getRightColumn()] + 1;
				} else {
					loc.otherBound = this[$getLeftColumn()] - 1;
				}
				
				if (loc.bound == this[$getRightColumn()] or loc.bound == this[$getLeftColumn()])
					return true;
					
				loc.sortArray = [this[$getLeftColumn()], this[$getRightColumn()], loc.bound, loc.otherBound];
				ArraySort(loc.sortArray, "numeric");
					
				loc.a = loc.sortArray[1];
				loc.b = loc.sortArray[2];
				loc.c = loc.sortArray[3];
				loc.d = loc.sortArray[4];
				
				switch (arguments.position) {
					case "child": { loc.newParent = arguments.target.key(); break; }
					case "root": { loc.newParent = "NULL"; break; }
					default: { loc.newParent = target[$getParentColumn()]; break; }
				}
			</cfscript>
			
			<cfquery name="loc.update" attributeCollection="#loc.queryArgs#">
				UPDATE 	#tableName()#
				SET 	#$getLeftColumn()# =	
							CASE 
								WHEN #$getLeftColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
									THEN #$getLeftColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
								WHEN #$getLeftColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#">
									THEN #$getLeftColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#">
								ELSE #$getLeftColumn()#
							END,
						#$getRightColumn()# = 	
							CASE 
								WHEN #$getRightColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
									THEN #$getRightColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
								WHEN #$getRightColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#">
									THEN #$getRightColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#">
								ELSE #$getRightColumn()#
							END,
						#$getParentColumn()# =
							CASE
								WHEN #$getIdColumn()# = <cfqueryparam cfsqltype="#$getIdType()#" value="#this[$getIdColumn()]#">
									THEN	<cfif arguments.position eq "root" or ($idsAreNullable() and not Len(loc.newParent))>
												NULL
											<cfelse>
												<cfqueryparam cfsqltype="#$getIdType()#" value="#loc.newParent#">
											</cfif>
								ELSE #$getParentColumn()#
							END
			</cfquery>

			<cfscript>
				if (IsObject(arguments.target))
					arguments.target.reload();
				this.reload();
			</cfscript>
			
			<cfif !$callback("afterMove")>
				<cftransaction action="rollback" />
			</cfif>
		</cftransaction>
		
		<cfreturn $callback("afterMove") />
	</cffunction>
	
	
	<!---
		all instance queries should scope their where clauses with the scope parameter
		passed into hasNestedSet()
	--->
	
	<cffunction name="$createScopedWhere" returntype="string" access="public" output="false">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="append" type="string" required="false" default="">
		
		<cfset var loc = {}>
		
		<cfset arguments.where = $appendWhereClause(argumentCollection=arguments)>

		<!--- loop over the list of scopes and add each one in turn --->
		<cfloop list="#$getScope()#" index="loc.property">
			<cfscript>
				loc.value = this[loc.property];
				if (!$propertyIsInteger(loc.property))
					loc.value = "'#loc.value#'";
				
				if (Len(arguments.where))
					arguments.where = arguments.where & " AND ";
				arguments.where = arguments.where & "#loc.property#=#loc.value#";
			</cfscript>
		</cfloop>
		
		<cfreturn arguments.where>
	</cffunction>
	
	
	<cffunction name="$appendWhereClause" returntype="string" access="public" output="false">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="append" type="string" required="false" default="">
		<cfscript>
			arguments.where = Trim(arguments.where);
			arguments.append = Trim(arguments.append);
			if (Len(arguments.append))
				if (Len(arguments.where))
					return arguments.where & " AND " & arguments.append;
				return arguments.append;
			return arguments.where;
		</cfscript>
	</cffunction>
	
	
	<!---
		developers should be able to pass in an object or key and we get the object
	--->
	<cffunction name="$getObject" returntype="any" access="public" output="false" mixin="model">
		<cfargument name="identifier" type="any" required="true" hint="An id or an object." />
		<cfscript>
			if (IsObject(arguments.identifier))
				return arguments.identifier;
			else if ($idIsValid(arguments.identifier))
				return findByKey(arguments.identifier);
			else
				return false;
		</cfscript>
	</cffunction>
	

</cfcomponent>