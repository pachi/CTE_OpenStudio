# -*- coding: utf-8 -*-
#
# Copyright (c) 2016 Ministerio de Fomento
#                    Instituto de Ciencias de la Construcción Eduardo Torroja (IETcc-CSIC)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author(s): Rafael Villar Burke <pachi@ietcc.csic.es>,
#            Daniel Jiménez González <dani@ietcc.csic.es>
#            Marta Sorribes Gil <msorribes@ietcc.csic.es>

HVEN_RES = "CTER24B_HVEN"
HVEN_RESNOC = "CTER24B_HVNOC"


# Ventilacion Residencial CTE:
# 1 - Redefine el horario de ventilación con caudal de diseño y ventilación nocturna en verano, CTER24B_HVEN (disponible en plantilla)
# 2 - Incorpora objetos ZoneVentilation:DesignFlowRate a zonas habitables, con horario CTER24B_HVEN
# Condiciones de ventilacion e infiltraciones para uso residencial segun CTE:
# Usa el modelo simple con ventilacion nocturna de 4 ren/h en verano para las zonas habitables y el caudal de diseno indicado en ren/h el resto del tiempo.
# Esta medida necesita otra complementaria de EPlus que corrige los horarios de las zonas si es necesario.

def cte_ventresidencial(model, runner, user_arguments)
  runner.registerInfo("CTE: Definición de condiciones de ventilación de espacios habitables en edificios residenciales.")

  # ------------------------------------------------------------------------------------------------------------------------------------
  # 1 - Redefine el horario de ventilación con caudal de diseño y ventilación nocturna en verano, CTER24B_HVEN (disponible en plantilla)
  # ------------------------------------------------------------------------------------------------------------------------------------
  design_flow_rate = runner.getDoubleArgumentValue('CTE_Design_flow_rate', user_arguments)
  heat_recovery = runner.getDoubleArgumentValue('CTE_Heat_recovery', user_arguments)
  fan_sfp = runner.getDoubleArgumentValue('CTE_Fan_sfp', user_arguments)
  fan_ntot = runner.getDoubleArgumentValue('CTE_Fan_ntot', user_arguments)
  usoEdificio = runner.getStringArgumentValue('CTE_Uso_edificio', user_arguments)

  #XXX: en terciario los recuperadores deben definirse en los sistemas
  if usoEdificio != 'Residencial'
    heat_recovery = 0.0
  end

  if heat_recovery >= 1.0
    runner.registerError("Recuperador de calor con eficiencia igual o mayor al 100%")
    return false
  end

  q_ven_reduced = design_flow_rate * (1 - heat_recovery)
  q_ven_noct = 4 - q_ven_reduced
  fan_sfp_augmented = fan_sfp / (1 - heat_recovery)
  ventilationPressureRise = fan_sfp_augmented * 1000 * fan_ntot # delta_p = SFP * n_tot, kPa -> Pa
  ventilationTotEfficiency = fan_ntot

  runner.registerValue("CTE Fan total efficiency", ventilationTotEfficiency)
  runner.registerValue("CTE Fan Pressure Rise (energy equivalent)", ventilationPressureRise, "Pa")
  runner.registerValue("CTE Fan SFP", fan_sfp, "kPa")
  runner.registerValue("CTE Fan SFP augmented", fan_sfp_augmented, "kPa")

  runner.registerInfo("[1/2] Definiendo horario con ventilacion nocturna en verano (4ren/h) y caudal de diseño: #{q_ven_reduced} [ren/h]")
  runner.registerValue("CTE caudal de ventilacion nocturna en verano", q_ven_noct, "[ren/h]")
  runner.registerValue("CTE caudal de ventilacion reducido con caudal de diseño y recuperacion", q_ven_reduced, "[ren/h]")

  scheduleRulesets = model.getScheduleRulesets
  scheduleRuleRES = scheduleRulesets.detect { |sch| sch.name.get == HVEN_RES }
  runner.registerInfo("* Localizado en el modelo el horario '#{ HVEN_RES }' de la plantilla: #{not scheduleRuleRES.nil?}")
  scheduleRuleNOC = scheduleRulesets.detect { |sch| sch.name.get == HVEN_RESNOC }
  runner.registerInfo("* Localizado en el modelo el horario '#{ HVEN_RESNOC }' de la plantilla: #{not scheduleRuleNOC.nil?}")

  def aplica_horario_a_semana(scheduleRule)
    scheduleRule.setApplyMonday(true)
    scheduleRule.setApplyTuesday(true)
    scheduleRule.setApplyWednesday(true)
    scheduleRule.setApplyThursday(true)
    scheduleRule.setApplyFriday(true)
    scheduleRule.setApplySaturday(true)
    scheduleRule.setApplySunday(true)
  end

  if scheduleRuleRES.nil?
    runner.registerInfo("* Creando horario '#{ HVEN_RES }'")
    # Reglas para ventilación de diseño
    scheduleRuleRES = OpenStudio::Model::ScheduleRuleset.new(model)
    scheduleRuleRES.setName(HVEN_RES)
    diaDisenoHVEN = OpenStudio::Model::ScheduleDay.new(model)
    diaDisenoHVEN.setName("Dia_tipo_ventilacion_diseNo")
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaDisenoHVEN.addValue(time_24h, 1.0)
    disenoHVENRule = OpenStudio::Model::ScheduleRule.new(scheduleRuleRES, diaDisenoHVEN)  # aquí añade la regla al horario
    disenoHVENRule.setName("Regla_de_ventilacion_de_diseNo")
    startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1)
    endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(12) , 31 )
    disenoHVENRule.setStartDate(startDate)
    disenoHVENRule.setEndDate(endDate)
    aplica_horario_a_semana(disenoHVENRule)
  end

  if scheduleRuleNOC.nil?
    runner.registerInfo("* Creando horario '#{ HVEN_RESNOC }'")
    # Reglas para ventilación de diseño
    scheduleRuleNOC = OpenStudio::Model::ScheduleRuleset.new(model)
    scheduleRuleNOC.setName(HVEN_RESNOC)
    # diaInvierno1
    diaInvierno1 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno1.setName("Dia_tipo1_ventilacion_nocturna_invierno")
    diaInvierno1.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.0) # 0 - 24h -> 0.0
    diaInvierno1Rule = OpenStudio::Model::ScheduleRule.new(scheduleRuleNOC, diaInvierno1)  # aquí añade la regla al horario
    diaInvierno1Rule.setName("Regla1_ventilacion_nocturna_invierno")
    diaInvierno1Rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1))
    diaInvierno1Rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5), 31))
    aplica_horario_a_semana(diaInvierno1Rule)
    #diaVerano
    diaVerano = OpenStudio::Model::ScheduleDay.new(model)
    diaVerano.setName("Dia_ventilacion_nocturna_verano")
    time_8h =  OpenStudio::Time.new(0, 8, 0, 0)
    time_24h =  OpenStudio::Time.new(0, 24, 0, 0)
    diaVerano.addValue(time_8h, 1.0) # 0 - 8h -> 1.0
    diaVerano.addValue(time_24h, 0.0) # 8h - 24h -> 0.0
    veranoRule = OpenStudio::Model::ScheduleRule.new(scheduleRuleNOC, diaVerano)
    veranoRule.setName("Regla_ventilacion_nocturna_verano")
    veranoRule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(6), 1))
    veranoRule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30))
    aplica_horario_a_semana(veranoRule)
    #diaInv2
    diaInvierno2 = OpenStudio::Model::ScheduleDay.new(model)
    diaInvierno2.setName("Dia_tipo2_ventilacion_nocturna_invierno")
    diaInvierno2.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0) # 0 -24h -> 0.0
    inviernoRule2 = OpenStudio::Model::ScheduleRule.new(scheduleRuleNOC, diaInvierno2)
    inviernoRule2.setName("Regla2_ventilacion_nocturna_invierno")
    inviernoRule2.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(10), 1))
    inviernoRule2.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(12), 31))
    aplica_horario_a_semana(inviernoRule2)
  end

  # ------------------------------------------------------------------------------------------------------------------------------------
  # 2 - Incorpora objetos ZoneVentilation:DesignFlowRate a zonas residenciales,
  #     con horario CTER24B_HVEN y CTE24B_HVNOC para caudal de diseño y ventilación nocturna, respectivamente
  # ------------------------------------------------------------------------------------------------------------------------------------

  runner.registerInfo("[2/2] Incorporando objetos ZoneVentilation:DesignFlowRate a espacios habitables")
  zones = model.getThermalZones
  runner.registerInfo("* Localizada(s) #{ zones.count } zona(s) térmica(s)")
  zoneVentilationCounter = 0
  spaceCounter = 0
  zones.each do | zone |
    zoneName = zone.name.get
    zoneIsIdeal = zone.useIdealAirLoads ? true : false
    spaces = zone.spaces()
    spaceCounter += spaces.count
    # XXX: Solamente usamos el primer espacio de la zona? suponemos que solo hay uno? Si hubiese más se duplicarían definiciones
    spaces.each do |space|
      spaceName = space.name.get
      spaceType = space.spaceType.get
      spaceTypeName = spaceType.name.get
      # Las zonas con Ideal Air Loads incorporan un objeto ZoneVentilation:DesignFlowRate si la
      # plantilla define para ese tipo de espacio un objeto 'Design Specification Outdoor Air'
      if zoneIsIdeal and not spaceType.isDesignSpecificationOutdoorAirDefaulted
          runner.registerWarning("- El espacio '#{ spaceName }' de la zona '#{ zoneName }' tiene sistemas ideales y un Objeto OutdoorAir en el tipo '#{ spaceTypeName }")
          next
      end
      # espacios habitables
      if spaceTypeName.start_with?('CTE_HR') or spaceTypeName.start_with?('CTE_AR')
        zoneVentilationCounter += 2
        zone_ventilation_noc = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zone_ventilation_noc.setName("HVNOC_#{spaceName}_Zone Ventilation Design Flow Rate NOCTURNO")
        zone_ventilation_noc.addToThermalZone(zone)
        zone_ventilation_noc.setVentilationType('Natural')
        zone_ventilation_noc.setDesignFlowRateCalculationMethod("AirChanges/Hour")
        zone_ventilation_noc.setAirChangesperHour(q_ven_noct)
        zone_ventilation_noc.setConstantTermCoefficient(1)
        zone_ventilation_noc.setTemperatureTermCoefficient(0)
        zone_ventilation_noc.setVelocityTermCoefficient(0)
        zone_ventilation_noc.setVelocitySquaredTermCoefficient(0)
        zone_ventilation_noc.setMinimumIndoorTemperature(-100)
        zone_ventilation_noc.setDeltaTemperature(-100)
        zone_ventilation_noc.setSchedule(scheduleRuleNOC)

        zone_ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zone_ventilation.setName("HVEN_#{spaceName}_Zone Ventilation Design Flow Rate NORMAL")
        zone_ventilation.addToThermalZone(zone)
        zone_ventilation.setVentilationType("Exhaust")
        zone_ventilation.setDesignFlowRateCalculationMethod("AirChanges/Hour")
        zone_ventilation.setAirChangesperHour(q_ven_reduced)
        zone_ventilation.setConstantTermCoefficient(1)
        zone_ventilation.setTemperatureTermCoefficient(0)
        zone_ventilation.setVelocityTermCoefficient(0)
        zone_ventilation.setVelocitySquaredTermCoefficient(0)
        zone_ventilation.setMinimumIndoorTemperature(-100)
        zone_ventilation.setDeltaTemperature(-100)
        zone_ventilation.setFanPressureRise(ventilationPressureRise)
        zone_ventilation.setFanTotalEfficiency(ventilationTotEfficiency)
        zone_ventilation.setSchedule(scheduleRuleRES)
      end
    end
  end
  runner.registerInfo("* Localizado(s) #{ spaceCounter } espacio(s)")
  runner.registerInfo("* Creado(s) #{ zoneVentilationCounter } objeto(s) ZoneVentilation:DesignFlowRate. ")
  runner.registerInfo("CTE: Finalizada definición de condiciones de ventilación de espacios habitables en edificios residenciales.")
  return true # OS necesita saber que todo acabó bien

end # end run
