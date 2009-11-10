<cfcomponent displayname="Nested Sets for CF Wheels">

	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
	Title:		Nested Sets Plugin for CF Wheels (http://cfwheels.org)
	
	Source:		http://github.com/liferealized/cfwheels-nested-set
	
	Authors:	James Gibson 	(me@iamjamesgibson.com)
				Andy Bellenie 	(andybellenie@gmail.com)

	History:	Created 	2009-10-31	James Gibson - First commit
				Modified 	2009-11-05 	Andy Bellenie - Added cfqueryparams, support for non-numeric keys, extra validation, bug fixes

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

	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="init" access="public" output="false" returntype="any">
		<cfset this.version = 1.0 />
		<cfreturn this />
	</cffunction>
		
	<cffunction name="hasNestedSet" returntype="void" access="public" output="false" mixin="model">
		<cfargument name="idColumn" type="string" default="">
		<cfargument name="parentColumn" type="string" default="parentId">
		<cfargument name="leftColumn" type="string" default="lft">
		<cfargument name="rightColumn" type="string" default="rgt">
		<cfargument name="scope" type="string" default="">
		<cfargument name="instantiateOnDelete" type="boolean" default="false">
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
			property(name="leaf", sql="(#arguments.rightColumn# - #arguments.leftColumn#)");
			// allow for the two new types of callbacks
			variables.wheels.class.callbacks.beforeMove = ArrayNew(1);
			variables.wheels.class.callbacks.afterMove = ArrayNew(1);
		</cfscript>
	</cffunction>
	
	
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		setup private accessors for our nested set values
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
					if (not StructKeyExists(this,ListGetAt(variables.wheels.class.nestedSet.scope,loc.i)))
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
		<cfif $propertyIsInteger($getIdColumn())>
			<cfreturn id>
		</cfif>
		<cfreturn "'#id#'">
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
		ex. model("user").root();
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="root" returntype="any" access="public" output="false">
		<cfscript>
			var loc = {
				  where = "#$getParentColumn()# IS NULL"
			};
			
			// merge in our where
			if (StructKeyExists(arguments, "where") and Len(arguments.where))
				arguments.where = loc.where & " AND " & arguments.where;
			else
				arguments.where = loc.where;
				
			// override any order passed in
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentcollection=arguments) />
	</cffunction>
	
	
	<cffunction name="roots" returntype="any" access="public" output="false">
		<cfscript>
			var loc = {
				  where = "#$getParentColumn()# IS NULL"
			};
			
			// merge in our where
			if (StructKeyExists(arguments, "where") and Len(arguments.where))
				arguments.where = loc.where & " AND " & arguments.where;
			else
				arguments.where = loc.where;
				
			// override our order
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	
	<cffunction name="isTreeValid" returntype="boolean" access="public" output="false">
		<cfscript>
			return leftAndRightIsValid() && noDuplicatesForColumns() && allRootsValid();
		</cfscript>
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
		<cfif ListLen($getScope()) gt 0>
			<cfloop list="#$getScope()#" index="loc.property">
			AND		nodes.#loc.property# = <cfqueryparam cfsqltype="#variables.wheels.class.properties[loc.property].type#" value="#this[loc.property]#">
			</cfloop>
		</cfif>
		
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
		<cfreturn this.eachRootValid(this.roots(argumentCollection=arguments)) />
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
		<cfthrow type="Wheels.NestedSet.NotImplemented" message="This method has not been implemented yet." />
	</cffunction>
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		instance level methods
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<!---
		Returns true if this is a root node
	--->
	<cffunction name="isRoot" returntype="boolean" access="public" output="false">
		<cfreturn $idIsValid(this[$getParentColumn()]) is false />
	</cffunction>
	
	<!---
		Returns true if this node has no children
	--->
	<cffunction name="isLeaf" returntype="boolean" access="public" output="false">
		<cfreturn !isNew() and (this[$getRightColumn()] - this[$getLeftColumn()] eq 1) />
	</cffunction>
	
	<!---
		Returns true if this node has a parent
	--->
	<cffunction name="isChild" returntype="boolean" access="public" output="false">
		<cfreturn $idIsValid(this[$getParentColumn()]) />
	</cffunction>
	
	<!---
		Returns the root node for itself
	--->
	<cffunction name="findRoot" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# <= #this[$getLeftColumn()]# AND #$getRightColumn()# >= #this[$getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of all parents to the root and itself
	--->
	<cffunction name="selfAndAncestors" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# <= #this[$getLeftColumn()]# AND #$getRightColumn()# >= #this[$getRightColumn()]#");
			arguments.order = $defaultOrder(direction="DESC");
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of all parents to the root
	--->
	<cffunction name="ancestors" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# < #this[$getLeftColumn()]# AND #$getRightColumn()# > #this[$getRightColumn()]#");
			arguments.order = $defaultOrder(direction="DESC");
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its siblings and itself
	--->
	<cffunction name="selfAndSiblings" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getParentColumn()# = #$formatIdForQuery(this[$getParentColumn()])#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its siblings
	--->
	<cffunction name="siblings" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getParentColumn()# = #$formatIdForQuery(this[$getParentColumn()])# AND #$getIdColumn()# != #$formatIdForQuery(this[$getIdColumn()])#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its nested children which do not have children
	--->
	<cffunction name="leaves" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]# AND leaf = 1");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>  
	
	<!---
        Returns the level of this object in the tree
        root level is 1	
	--->
	<cffunction name="level" returntype="numeric" access="public" output="false">
		<cfscript>
			if (not IsNumeric(this[$getParentColumn()]))
				return 1;
		</cfscript>
		<cfreturn selfAndAncestors(returnAs="query").RecordCount />
	</cffunction>
	
	<!---
		Returns a set of itself and all of its nested children
	--->
	<cffunction name="selfAndDescendants" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# >= #this[$getLeftColumn()]# AND #$getRightColumn()# <= #this[$getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its children and nested children
	--->
	<cffunction name="descendants" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="isDescendantOf" returntype="boolean" access="public" output="false">
		<cfargument name="other" type="any" required="true" />
		<cfset arguments.other = $getObject(arguments.other) />
		<cfreturn (arguments.other[$getLeftColumn()] lt this[$getLeftColumn()] and this[$getLeftColumn()] lt arguments.other[$getRightColumn()] and isSameScope(arguments.other)) />
	</cffunction>
	
	<cffunction name="isAncestorOf" returntype="boolean" access="public" output="false">
		<cfargument name="other" type="any" required="true" />
		<cfset arguments.other = $getObject(arguments.other) />
		<cfreturn (this[$getLeftColumn()] lt arguments.other[$getLeftColumn()] and arguments.other[$getLeftColumn()] lt this[$getRightColumn()] and isSameScope(arguments.other)) />
	</cffunction>
	
	<!---
		check to see of the other model has the same scope values
	--->
	<cffunction name="isSameScope" returntype="boolean" access="public" output="false">
		<cfargument name="other" type="any" required="true" />
		<cfscript>
			var loc = { 
				  iEnd = ListLen($getScope())
			};
			
			if (Len($getScope()))
			{
				arguments.other = $getObject(arguments.other);
				for (loc.i=1; loc.i lte loc.iEnd; loc.i++)
					if (this[ListGetAt($getScope(), loc.i)] != other[ListGetAt($getScope(), loc.i)])
						return false;
			}
			return true;
		</cfscript>
	</cffunction>
	
	<!---
		Find the first sibling to the left
	--->
	<cffunction name="leftSibling" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getRightColumn()# = #this[$getLeftColumn()] - 1# AND #$getParentColumn()# = #this[$getParentColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Find the first sibling to the right
	--->
	<cffunction name="rightSibling" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#$getLeftColumn()# = #this[$getRightColumn()] + 1#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		shorthand method for finding the left sibling and moving to the left of it.
	--->
	<cffunction name="moveLeft" returntype="boolean" access="public" output="false" mixin="model">
		<cfreturn moveToLeftOf(leftSibling())>
	</cffunction>
	
	<!---
		shorthand method for finding the right sibling and moving to the right of it.
	--->
	<cffunction name="moveRight" returntype="boolean" access="public" output="false" mixin="model">
		<cfreturn moveToRightOf(rightSibling())>
	</cffunction>
	
	<!---
		Move the node to the left of another node (you can pass id or object)
	--->
	<cffunction name="moveToLeftOf" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target)>
			<cfreturn $moveTo(arguments.target,"left")>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	<!---
		Move the node to the right of another node (you can pass id or object)
	--->
	<cffunction name="moveToRightOf" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target)>
			<cfreturn $moveTo(arguments.target, "right")>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	<!---
		Move the node to the child of another node (you can pass id or object)
	--->
	<cffunction name="moveToChildOf" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true">
		<cfset arguments.target = $getObject(arguments.target)>
		<cfif IsObject(arguments.target)>
			<cfreturn $moveTo(arguments.target, "child")>
		</cfif>
		<cfreturn false>
	</cffunction>
	
	<!---
		move this object to the root
		ends up reloading the object once the update is complete
	--->
	<cffunction name="moveToRoot" returntype="boolean" access="public" output="false" mixin="model">
		<cfreturn $moveTo("", "root") />
	</cffunction>
	
	<!---
		check to make sure we are not trying to move a node 
		somewhere it shouldn't be
	--->
	<cffunction name="isMovePossible" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="component" required="true" />
		<cfscript>
			if (this.key() == target.key() or not isSameScope(other=target))
				return false;
		
			if (((this[$getLeftColumn()] lte target[$getLeftColumn()] and this[$getRightColumn()] gte target[$getLeftColumn()]) 
				or (this[$getLeftColumn()] lte target[$getRightColumn()] and this[$getRightColumn()] gte target[$getRightColumn()])))
				return false;
		</cfscript>
		<cfreturn true />
	</cffunction>
	
	<cffunction name="toText" returntype="string" access="public" output="false" mixin="model">
		<cfthrow type="Wheels.NestedSet.NotImplemented" message="This method has not been implemented yet." />
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
				if (not isSameScope(parent))
					$throw(type="Wheels.Plugins.NestedSet.ScopeMismatch",message="The supplied parent is not within the same scope as the item you are trying to insert.");
				else
					moveToChildOf(parent);
			else
				moveToRoot(); // if empty or a different scope then we are a root node*/
		</cfscript>
		<cfreturn true><!--- force the save even if we did nothing --->
	</cffunction>
	
	
	<cffunction name="$setDefaultLeftAndRight" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {
				  maxRight = this.maximum(property=getRightColumn())
				, leftColumn = loc.maxRight + 1
				, rightColumn = loc.maxRight + 2
			};
			
			this[$getLeftColumn()] = loc.leftColumn;
			this[$getRightColumn()] = loc.rightColumn;
		</cfscript>
		<cfreturn true />
	</cffunction>
	
	<!---
		removes all descendants of itself before being deleted
		if you would like callbacks to run for each object deleted, simply
		pass the argument instanciateOnDelete=true into hasNestedSet() 
	--->
	<cffunction name="$deleteDescendants" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {};	
			
			// andybellenie 20091105: not sure what this is for...
			if (not IsNumeric(this[$getRightColumn()]) or not IsNumeric(this[$getLeftColumn()]))
				return true;
				
			arguments.where = $createScopedWhere("#$getLeftColumn()# > #this[$getLeftColumn()]# AND #$getRightColumn()# < #this[$getRightColumn()]#");
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
				SET 	#$getLeftColumn()# =	CASE 
													WHEN #$getLeftColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
														THEN #$getLeftColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
													WHEN #$getLeftColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#">
														THEN #$getLeftColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#">
													ELSE #$getLeftColumn()#
												END,
						#$getRightColumn()# = 	CASE 
													WHEN #$getRightColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
														THEN #$getRightColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.b#">
													WHEN #$getRightColumn()# BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.d#">
														THEN #$getRightColumn()# + <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.a#"> - <cfqueryparam cfsqltype="cf_sql_integer" value="#loc.c#">
													ELSE #$getRightColumn()#
												END,
						#$getParentColumn()# = 	CASE
													WHEN #$getIdColumn()# = <cfqueryparam cfsqltype="#$getIdType()#" value="#this[$getIdColumn()]#">
														THEN	<cfif arguments.position eq "root">
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
		<cfset var loc = {where=arguments.where}>
		<cfloop list="#$getScope()#" index="loc.property">
			<cfscript>
				loc.value = this[loc.property];
				if (!$propertyIsInteger(loc.property))
					loc.value = "'#loc.value#'";
				if (Len(loc.where))
					loc.where = loc.where & " AND ";
				loc.where = loc.where & "#loc.property#=#loc.value#";
			</cfscript>
		</cfloop>
		<cfreturn loc.where>
	</cffunction>	
	
	
	<!---
		all instance queries should be sorted by the left property
	--->
	<cffunction name="$defaultOrder" returntype="string" access="public" output="false">
		<cfargument name="direction" type="string" default="ASC">
		<cfreturn "#variables.wheels.class.nestedSet.leftColumn# #arguments.direction#" />
	</cffunction>

	
	<!---
		developers should be able to pass in an object or key and we get the object
	--->
	<cffunction name="$getObject" returntype="any" access="public" output="false" mixin="model">
		<cfargument name="identifier" type="any" required="true" hint="An id or object" />
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
