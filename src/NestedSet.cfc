<cfcomponent>

	<cffunction name="init" access="public" output="false" returntype="any">
		<cfset this.version = 1.0 />
		<cfreturn this />
	</cffunction>
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		use actsAsNestedSet() in your model init to setup for the methods below
		defaults
			- parentColumn = parentId
			- leftColumn = lft
			- rightColumn = rgt
			- scope = ""
			- instantiateOnDelete = false
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="actsAsNestedSet" returntype="void" access="public" output="false" mixin="model">
		<cfargument name="parentColumn" type="string" required="false" default="parentId" />
		<cfargument name="leftColumn" type="string" required="false" default="lft" />
		<cfargument name="rightColumn" type="string" required="false" default="rgt" />
		<cfargument name="scope" type="string" required="false" default="" />
		<cfargument name="instantiateOnDelete" type="boolean" required="false" default="false" />
		<cfscript>
			variables.wheels.class.nestedSet = {
				  parentColumn = arguments.parentColumn
				, leftColumn = arguments.leftColumn
				, rightColumn = arguments.rightColumn
				, scope = Replace(arguments.scope, ", ", ",", "all")
				, instantiateOnDelete = arguments.instantiateOnDelete
			};
			
			beforeCreate(methods="$setDefaultLeftAndRight");
			beforeSave(methods="$storeNewParent");
			afterSave(methods="$moveToNewParent");
			beforeDelete(methods="$deleteDecendants");
			
			// add in a calculated property for the leaf value
			property(name="leaf", sql="(#getRightColumn()# - #getLeftColumn()#)");
			
			// allow for our two new types of callbacks
			loc.newCallbacks = "beforeMove,afterMove";
			loc.iEnd = ListLen(loc.newCallbacks);
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
				variables.wheels.class.callbacks[ListGetAt(loc.newCallbacks, loc.i)] = ArrayNew(1);
		</cfscript>
	</cffunction>
	
	<!-----------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		setup accessors for our nested set values
	-------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------>	
	
	<cffunction name="getParentColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSetScopeExists() />
		<cfreturn variables.wheels.class.nestedSet.parentColumn />
	</cffunction>
	
	<cffunction name="getLeftColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSetScopeExists() />
		<cfreturn variables.wheels.class.nestedSet.leftColumn />
	</cffunction>
	
	<cffunction name="getRightColumn" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSetScopeExists() />
		<cfreturn variables.wheels.class.nestedSet.rightColumn />
	</cffunction>
	
	<cffunction name="getScope" returntype="string" access="public" output="false" mixin="model">
		<cfset $validateNestedSetScopeExists() />
		<cfreturn variables.wheels.class.nestedSet.scope />
	</cffunction>
	
	<cffunction name="getInstantiateOnDelete" returntype="boolean" access="public" output="false" mixin="model">
		<cfset $validateNestedSetScopeExists() />
		<cfreturn variables.wheels.class.nestedSet.instantiateOnDelete />
	</cffunction>
	
	<cffunction name="$validateNestedSetScopeExists" returntype="void" access="public" output="false" mixin="model">
		<cfscript>
			if (not StructKeyExists(variables.wheels.class, "nestedSet"))
				$throw(type="Wheels.NestedSet.SetupNotComplete", message="You must first call `actsAsNestedSet()` from your models init to use NestedSet methods.");
		</cfscript>
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
				  where = "#getParentColumn()# IS NULL"
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
	
	<cffunction name="roots">
		<cfscript>
			var loc = {
				  where = "#getParentColumn()# IS NULL"
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
			return leftAndRightsValid() && noDuplicatesForColumns() && allRootsValid();
		</cfscript>
	</cffunction>
	
	<cffunction name="leftAndRightsValid" returntype="boolean" access="public" output="false">
		<cfscript>
			var loc = {
				  where = ""
				, queryArgs = StructCopy(variables.wheels.class.connection)
			};
			
			loc.where = ListAppend(loc.where, "(#tableName()#.#getLeftColumn()# IS NULL OR", " ");
			loc.where = ListAppend(loc.where, "#tableName()#.#getRightColumn()# IS NULL OR", " ");
			loc.where = ListAppend(loc.where, "#tableName()#.#getLeftColumn()# >= #tableName()#.#getRightColumn()# OR", " ");
			loc.where = ListAppend(loc.where, "(#tableName()#.#getParentColumn()# IS NOT NULL AND", " ");
			loc.where = ListAppend(loc.where, "(#tableName()#.#getLeftColumn()# <= parent.#getLeftColumn()# OR", " ");
			loc.where = ListAppend(loc.where, "#tableName()#.#getRightColumn()# >= parent.#getRightColumn()#)))", " ");
		</cfscript>
		
		<cfquery name="loc.query" attributeCollection="#loc.queryArgs#">
			SELECT COUNT(*) as leftRightCount
			FROM #tableName()# LEFT OUTER JOIN #tableName()# AS parent ON #tableName()#.parent = parent.id
			WHERE #loc.where#
		</cfquery>
		
		<cfreturn (loc.query.leftRightCount eq 0) />
	</cffunction>
	
	<cffunction name="noDuplicatesForColumns">
		<cfscript>
			var loc = {
				  select = getScope()
				, columns = ListAppend(getLeftColumn(), getRightColumn())
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
				GROUP BY #loc.columns#
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
			
				if (arguments.roots[getLeftColumn()][loc.i] gt loc.lft and arguments.roots[getRightColumn()][loc.i] gt loc.rgt) {
				
					loc.lft = arguments.roots[getLeftColumn()][loc.i];
					loc.rgt = arguments.roots[getRightColumn()][loc.i];

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
		<cfreturn !IsNumeric(this[getParentColumn()]) />
	</cffunction>
	
	<!---
		Returns true if this node has no children
	--->
	<cffunction name="isLeaf" returntype="boolean" access="public" output="false">
		<cfreturn !isNew() and (this[getRightColumn()] - this[getLeftColumn()] eq 1) />
	</cffunction>
	
	<!---
		Returns true if this node has a parent
	--->
	<cffunction name="isChild" returntype="boolean" access="public" output="false">
		<cfreturn IsNumeric(this[getParentColumn()]) />
	</cffunction>
	
	<!---
		Returns the root node for itself
	--->
	<cffunction name="findRoot" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# <= #this[getLeftColumn()]# AND #getRightColumn()# >= #this[getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of all parents to the root and itself
	--->
	<cffunction name="selfAndAncestors" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# <= #this[getLeftColumn()]# AND #getRightColumn()# >= #this[getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of all parents to the root
	--->
	<cffunction name="ancestors" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# < #this[getLeftColumn()]# AND #getRightColumn()# > #this[getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its direct children and itself
	--->
	<cffunction name="selfAndSiblings" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getParentColumn()# = #this[getParentColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its direct children
	--->
	<cffunction name="siblings" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getParentColumn()# = #this[getParentColumn()]# AND #primaryKey()# != #key()#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its nested children which do not have children
	--->
	<cffunction name="leaves" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# > #this[getLeftColumn()]# AND #getRightColumn()# < #this[getRightColumn()]# AND leaf = 1");
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
			if (not IsNumeric(this[getParentColumn()]))
				return 1;
		</cfscript>
		<cfreturn selfAndAncestors(returnAs="query").RecordCount />
	</cffunction>
	
	<!---
		Returns a set of itself and all of its nested children
	--->
	<cffunction name="selfAndDescendants" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# >= #this[getLeftColumn()]# AND #getRightColumn()# <= #this[getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Returns a set of all of its children and nested children
	--->
	<cffunction name="descendants" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# > #this[getLeftColumn()]# AND #getRightColumn()# < #this[getRightColumn()]#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findAll(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="isDecendantOf" returntype="boolean" access="public" output="false">
		<cfargument name="other" type="any" required="true" />
		<cfset arguments.other = $getObject(arguments.other, "other") />
		<cfreturn (arguments.other[getLeftColumn()] lt this[getLeftColumn()] and this[getLeftColumn()] lt arguments.other[getRightColumn()] and isSameScope(arguments.other)) />
	</cffunction>
	
	<cffunction name="isAncestorOf" returntype="boolean" access="public" output="false">
		<cfargument name="other" type="any" required="true" />
		<cfset arguments.other = $getObject(arguments.other, "other") />
		<cfreturn (this[getLeftColumn()] lt arguments.other[getLeftColumn()] and arguments.other[getLeftColumn()] lt this[getRightColumn()] and isSameScope(arguments.other)) />
	</cffunction>
	
	<!---
		check to see of the other model has the same scope values
	--->
	<cffunction name="isSameScope" returntype="boolean" access="public" output="false">
		<cfargument name="other" type="any" required="true" />
		<cfscript>
			var loc = { 
				  iEnd = ListLen(getScope())
			};
			
			arguments.other = $getObject(arguments.other, "other");
			
			for (loc.i=1; loc.i lte loc.iEnd; loc.i++)
				if (this[ListGetAt(getScope(), loc.i)] != other[ListGetAt(getScope(), loc.i)])
					return false;
		</cfscript>
		<cfreturn true />
	</cffunction>
	
	<!---
		Find the first sibling to the left
	--->
	<cffunction name="leftSibling" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getRightColumn()# = #this[getLeftColumn()] - 1#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		Find the first sibling to the right
	--->
	<cffunction name="rightSibling" returntype="any" access="public" output="false">
		<cfscript>
			arguments.where = $createScopedWhere("#getLeftColumn()# = #this[getRightColumn()] + 1#");
			arguments.order = $defaultOrder();
		</cfscript>
		<cfreturn findOne(argumentCollection=arguments) />
	</cffunction>
	
	<!---
		shorthand method for finding the left sibling and moving to the left of it.
	--->
	<cffunction name="moveLeft" returntype="boolean" access="public" output="false" mixin="model">
		<cfreturn moveToLeftOf(leftSibling()) />
	</cffunction>
	
	<!---
		shorthand method for finding the right sibling and moving to the right of it.
	--->
	<cffunction name="moveRight" returntype="boolean" access="public" output="false" mixin="model">
		<cfreturn moveToRightOf(rightSibling()) />
	</cffunction>
	
	<!---
		Move the node to the left of another node (you can pass id or object)
	--->
	<cffunction name="moveToLeftOf" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true" />
		<cfreturn $moveTo(arguments.target, "left") />
	</cffunction>
	
	<!---
		Move the node to the right of another node (you can pass id or object)
	--->
	<cffunction name="moveToRightOf" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true" />
		<cfreturn $moveTo(arguments.target, "right") />
	</cffunction>
	
	<!---
		Move the node to the child of another node (you can pass id or object)
	--->
	<cffunction name="moveToChildOf" returntype="boolean" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true" />
		<cfreturn $moveTo(arguments.target, "child") />
	</cffunction>
	
	<!---
		move this object to the root
		ends up reloading the object once the update is complete
	--->
	<cffunction name="moveToRoot" returntype="boolean" access="public" output="false" mixin="model">
		<cfreturn $moveTo(0, "root") />
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
		
			if (((this[getLeftColumn()] lte target[getLeftColumn()] and this[getRightColumn()] gte target[getLeftColumn()]) 
				or (this[getLeftColumn()] lte target[getRightColumn()] and this[getRightColumn()] gte target[getRightColumn()])))
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
	
	<cffunction name="$storeNewParent" returntype="boolean" access="public" output="false" mixin="model">
		<cfset this.moveToNewParentId = IIf(hasChanged(property=getParentColumn()), "this[getParentColumn()]", "false") />
		<cfreturn true />
	</cffunction> 
	
	<cffunction name="$moveToNewParent" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			if (not StructKeyExists(this, "moveToNewParentId"))
				moveToRoot();
			else if (this.moveToNewParentId)
				moveToChildOf(this.moveToNewParentId);
		</cfscript>
	</cffunction>
	
	
	<cffunction name="$setDefaultLeftAndRight" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {
				  where = $createScopedWhere()
			};
			
			loc.maxRight = this.maximum(property=getRightColumn(), where=loc.where);
			
			this[getLeftColumn()] = loc.maxRight + 1;
			this[getRightColumn()] = loc.maxRight + 2;
		</cfscript>
		<cfreturn true />
	</cffunction>
	
	<!---
		removes all decendants of itself before being deleted
		if you would like callbacks to run for each object deleted, simply
		pass the argument instanciateOnDelete=true into actsAsNestedSet() 
	--->
	<cffunction name="$deleteDecendants" returntype="boolean" access="public" output="false" mixin="model">
		<cfscript>
			var loc = {
				  where = $createScopedWhere("#getLeftColumn()# > #this[getLeftColumn()]# AND #getRightColumn()# < #this[getRightcolumn()]#")
			};	
			
			if (not Len(this[getRightColumn()]) or not Len(this[getLeftColumn()]) or this.skipBeforeDestroy)
				return true;	
		</cfscript>
		<cftransaction action="begin">
			<cfscript>
				if (StructKeyExists(arguments, "where") and Len(arguments.where))
					arguments.where = arguments.where & " AND " & loc.where;
				else
					arguments.where = loc.where;
				
				deleteAll(argumentCollection=arguments, instantiate=getIsnstantiateOnDelete());
			
				loc.diff = this[getRightcolumn()] - this[getLeftColumn()] + 1;
			</cfscript>
	
			<cfquery datasource="#variables.wheels.class.connection.datasource#" name="loc.query">
				UPDATE #tableName()# 
				SET #getLeftColumn()# = #getLeftColumn()# - #loc.diff# 
				WHERE #$createScopedWhere("#getLeftColumn()# > #this[getRightColumn()]#")#;
				
				UPDATE #tableName()# 
				SET #getRightcolumn()# = #getRightcolumn()# - #loc.diff# 
				WHERE #$createScopedWhere("#getRightColumn()# > #this[getRightColumn()]#")#;
			</cfquery>
		</cftransaction>
		<cfreturn true />
	</cffunction>
	
	<!---
		core private method used to move items around in the tree
		update is scoped accordingly
	--->
	<cffunction name="$moveTo" returntype="any" access="public" output="false" mixin="model">
		<cfargument name="target" type="any" required="true" />
		<cfargument name="position" type="string" required="true" hint="may be one of `child, left, right, root`" />
		<cfscript>
			var loc = {
				  queryArgs = variables.wheels.class.connection
			};
		</cfscript>
		<cftransaction action="begin">
			<cfscript>
				
				if (isNew())
					$throw(type="Wheels.NestedSet.MoveNotAllowed", message="You cannot move a new node!");
					
				if (!$callback("beforeMove"))
					return false;
				
				if (IsObject(arguments.target))
					arguments.target.reload();
				else if (IsNumeric(arguments.target))
					target = findByKey(arguments.target);
				else
					$throw(type="Wheels.NestedSet.ArgumentTypeMismatch", message="The argument target must be an object or a numeric value.");
					
				// reload this object so we have the freshest data
				this.reload();
				
				// make sure we can do the move
				if (arguments.position != "root" and !isMovePossible(arguments.target))
					$throw(type="Wheels.NestedSet.MoveNotAllowed", message="Impossible move, target node cannot be inside moved tree.");
				
				switch (arguments.position) {
				
					case "child": { loc.bound = target[getRightColumn()];     break; }
					case "left":  { loc.bound = target[getleftColumn()];      break; }
					case "right": { loc.bound = target[getRightColumn()] + 1; break; }
					case "root":  { loc.bound = 1; break; }
					default: {
						$throw(type="Wheels.NestedSet.IncorrectArgumentValue", message="Position should be `child`, `left`, `right` or `root` (`#arguments.position#` received).");
					}
				}
				
				if (loc.bound gt this[getRightColumn()]) {
					loc.bound--;
					loc.otherBound = this[getRightColumn()] + 1;
				} else {
					loc.otherBound = this[getLeftColumn()] - 1;
				}
				
				if (loc.bound == this[getRightColumn()] or loc.bound == this[getLeftColumn()])
					return true;
					
				loc.sortArray = [this[getLeftColumn()], this[getRightColumn()], loc.bound, loc.otherBound];
				ArraySort(loc.sortArray, "numeric");
					
				loc.a = loc.sortArray[1];
				loc.b = loc.sortArray[2];
				loc.c = loc.sortArray[3];
				loc.d = loc.sortArray[4];
				
				switch (arguments.position) {
				
					case "child": { loc.newParent = target.key(); break; }
					case "root": { loc.newParent = "NULL"; break; }
					default: { loc.newParent = target[getParentColumn()]; break; }
				}
			</cfscript>
			
			<cfquery name="loc.update" attributeCollection="#loc.queryArgs#">
				UPDATE #tableName()#
				SET #getLeftColumn()# = CASE 
											WHEN #getLeftColumn()# BETWEEN #loc.a# AND #loc.b#
												THEN #getLeftColumn()# + #loc.d# - #loc.b#
											WHEN #getLeftColumn()# BETWEEN #loc.c# AND #loc.d#
												THEN #getLeftColumn()# + #loc.a# - #loc.c#
											ELSE #getLeftColumn()#
										END,
					#getRightColumn()# = CASE 
											WHEN #getRightColumn()# BETWEEN #loc.a# AND #loc.b#
												THEN #getRightColumn()# + #loc.d# - #loc.b#
											WHEN #getRightColumn()# BETWEEN #loc.c# AND #loc.d#
												THEN #getRightColumn()# + #loc.a# - #loc.c#
											ELSE #getRightColumn()#
										END,
					#getParentColumn()# = CASE
											WHEN #primaryKey()# = #this[primaryKey()]#
												THEN #loc.newParent#
											ELSE #getParentColumn()#
										END
				WHERE #$createScopedWhere()#		
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
		all instance queries should scope there where clauses with the scope parameter
		passed into actsAsNestedSet()
	--->
	<cffunction name="$createScopedWhere" returntype="string" access="public" output="false">
		<cfargument name="where" type="string" required="false" default="" />
		<cfscript>
			var loc = {
				  scope = variables.wheels.class.nestedSet.scope
				, where = arguments.where
			};
			
			loc.iEnd = ListLen(loc.scope);
			
			for (loc.i=1; loc.i lte loc.iEnd; loc.i++)
			{
				if (Len(loc.where))
					loc.where = loc.where & " AND ";
				loc.property = Trim(ListGetAt(loc.scope, loc.i));
				loc.where = loc.where & loc.property & "=";
				if (!IsNumeric(this[loc.property]))
					loc.where = loc.where & "'";
				loc.where = loc.where & this[loc.property];
				if (!IsNumeric(this[loc.property]))
					loc.where = loc.where & "'";
			}
		</cfscript>
		<cfreturn loc.where />
	</cffunction>
	
	<!---
		all instance queries should be sorted by the left property
	--->
	<cffunction name="$defaultOrder" returntype="string" access="public" output="false">
		<cfreturn "#variables.wheels.class.nestedSet.leftColumn# ASC" />
	</cffunction>
	
	<!---
		developers should be able to pass in an object or key and we get the object
	--->
	<cffunction name="$getObject" returntype="any" access="public" output="false" mixin="model">
		<cfargument name="identifier" type="any" required="true" hint="An id or object" />
		<cfargument name="argumentName" type="string" required="true" />
		<cfscript>
			if (not IsObject(arguments.identifier) and not IsNumeric(arguments.identifier))
				$throw(type="Wheels.NestedSet.ArgumentTypeMismatch", message="The argument `#arguments.argumentName#` must be an object or a numeric value.");
				
			if (IsNumeric(arguments.identifier))
				arguments.identifier = findByKey(arguments.identifier);
		</cfscript>
		<cfreturn arguments.identifier />
	</cffunction>
	
</cfcomponent>