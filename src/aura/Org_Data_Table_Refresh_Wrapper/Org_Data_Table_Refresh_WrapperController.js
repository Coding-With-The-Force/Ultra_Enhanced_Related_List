/**
 * Created by gerry on 3/8/2021.
 */

({
	doInit : function(component, event, helper){
		helper.getObjectLabel(component, component.get("v.relatedObjectName"), "v.relatedObjectLabel");
		helper.getObjectLabel(component, component.get("v.editableRelatedObjectType"), "v.editableRelatedObjectLabel");
	},

	doToastRefresh : function(component, event, helper) {
		const relatedObjectName = component.get("v.editableRelatedObjectLabel").toUpperCase();
		const objectName = component.get("v.relatedObjectLabel").toUpperCase();
		let templateData = event.getParam("messageTemplateData");
		console.log('This is the template data ::: ' + templateData);
		if(templateData) {
			templateData.forEach(message => {
				console.log('This is the message ::: ' + message.toUpperCase() + ' ::: This is the object name ::: ' + objectName + ' This is the related object name ::: ' + relatedObjectName);
				if (message.toUpperCase().includes(objectName) || message.toUpperCase().includes(relatedObjectName)) {
					component.find("enhanced_list").getTableData();
				}
			});
		}
	},

	doTableRefresh : function(component, event, helper){
		component.find("enhanced_list").getTableData();
	}
})