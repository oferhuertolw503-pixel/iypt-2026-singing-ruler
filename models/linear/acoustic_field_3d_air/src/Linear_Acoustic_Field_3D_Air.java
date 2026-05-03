import com.comsol.model.*;
import com.comsol.model.util.*;
import java.io.File;
import java.util.Locale;

public class Linear_Acoustic_Field_3D_Air {
  public static Model run() {
    ModelUtil.clear();
    Model model = ModelUtil.create("Model");
    model.modelPath(".");
    model.label("linear_acoustic_field_3d_air.mph");

    model.param().set("L_free", "0.20[m]");
    model.param().set("b", "0.03[m]");
    model.param().set("h_ruler", "0.002[m]");
    model.param().set("rho", "7930[kg/m^3]");
    model.param().set("E", "193e9[Pa]");
    model.param().set("nu", "0.29");
    model.param().set("root", "ideal_clamp");
    model.param().set("tip", "free");
    model.param().set("excitation_mode", "impact");
    model.param().set("x0", "0.85*L_free");
    model.param().set("use_impulse", "1");
    model.param().set("J", "0.04[N*s]");
    model.param().set("tau_imp", "2e-3[s]");
    model.param().set("pulse_shape", "half_sine");
    model.param().set("impact_patch_dx", "0.010[m]");
    model.param().set("impact_patch_dy", "0.006[m]");
    model.param().set("zeta_struct", "0.015");
    model.param().set("f_damp_low", "40[Hz]");
    model.param().set("f_damp_high", "700[Hz]");
    model.param().set("eigen_modes", "6");
    model.param().set("time_end", "1[s]");
    model.param().set("time_step", "1e-4[s]");
    model.param().set("mesh_numelem", "40");
    model.param().set("use_real_air_domain", "1");
    model.param().set("air_shape", "sphere");
    model.param().set("air_radius", "0.12[m]");
    model.param().set("rho_air", "1.225[kg/m^3]");
    model.param().set("c_air", "343[m/s]");
    model.param().set("mic_x", "L_free/2");
    model.param().set("mic_y", "0[m]");
    model.param().set("mic_z", "0.02[m]");
    model.param().set("mic_offset_from_surface_m", "0.02[m]");
    model.param().set("radiation_source_x", "L_free/2");
    model.param().set("radiation_source_y", "0[m]");
    model.param().set("radiation_source_z", "0[m]");

    // __LINEAR_PARAM_BLOCK__

    model.param().set("t_imp_start", "5*time_step");
    model.param().set("t_imp_stop", "t_imp_start+tau_imp");
    model.param().set("Fimp", "use_impulse*if(t<t_imp_start,0,if(t>t_imp_stop,0,(pi*J/(2*tau_imp))*sin(pi*(t-t_imp_start)/tau_imp)))");
    model.param().set("impact_xmin", "max(0[m],x0-impact_patch_dx/2)");
    model.param().set("impact_xmax", "min(L_free,x0+impact_patch_dx/2)");
    model.param().set("impact_ymin", "max(-b/2,-impact_patch_dy/2)");
    model.param().set("impact_ymax", "min(b/2,impact_patch_dy/2)");
    model.param().set("impact_cx", "(impact_xmin+impact_xmax)/2");
    model.param().set("impact_cy", "(impact_ymin+impact_ymax)/2");
    model.param().set("impact_wx", "max(1e-9[m],impact_xmax-impact_xmin)");
    model.param().set("impact_wy", "max(1e-9[m],impact_ymax-impact_ymin)");
    model.param().set("impact_shape_x", "if(abs(x-impact_cx)<=impact_wx/2,0.5*(1+cos(2*pi*(x-impact_cx)/impact_wx)),0)");
    model.param().set("impact_shape_y", "if(abs(y-impact_cy)<=impact_wy/2,0.5*(1+cos(2*pi*(y-impact_cy)/impact_wy)),0)");
    model.param().set("impact_shape_area_norm", "4*impact_shape_x*impact_shape_y/(impact_wx*impact_wy)");
    model.param().set("fimp_z_area", "-Fimp*impact_shape_area_norm");
    model.param().set("force_z_total", "-Fimp");
    model.param().set("alpha_dM_struct", "4*pi*zeta_struct*f_damp_low*f_damp_high/(f_damp_low+f_damp_high)");
    model.param().set("beta_dK_struct", "zeta_struct/(pi*(f_damp_low+f_damp_high))");
    model.param().set("air_cx", "L_free/2");
    model.param().set("air_cy", "0[m]");
    model.param().set("air_cz", "0[m]");
    model.component().create("comp1", true);
    model.component("comp1").geom().create("geom1", 3);
    model.component("comp1").geom("geom1").lengthUnit("m");

    model.component("comp1").geom("geom1").create("blkRuler", "Block");
    model.component("comp1").geom("geom1").feature("blkRuler").set("size", new String[] { "L_free", "b", "h_ruler" });
    model.component("comp1").geom("geom1").feature("blkRuler").set("pos", new String[] { "0", "-b/2", "-h_ruler/2" });
    model.component("comp1").geom("geom1").feature("blkRuler").set("selresult", true);
    model.component("comp1").geom("geom1").feature("blkRuler").set("selresultshow", "all");

    model.component("comp1").geom("geom1").create("blkVoid", "Block");
    model.component("comp1").geom("geom1").feature("blkVoid").set("size", new String[] { "L_free", "b", "h_ruler" });
    model.component("comp1").geom("geom1").feature("blkVoid").set("pos", new String[] { "0", "-b/2", "-h_ruler/2" });
    model.component("comp1").geom("geom1").feature("blkVoid").set("selresult", true);
    model.component("comp1").geom("geom1").feature("blkVoid").set("selresultshow", "all");

    model.component("comp1").geom("geom1").create("sphAir", "Sphere");
    model.component("comp1").geom("geom1").feature("sphAir").set("r", "air_radius");
    model.component("comp1").geom("geom1").feature("sphAir").set("pos", new String[] { "air_cx", "air_cy", "air_cz" });
    model.component("comp1").geom("geom1").feature("sphAir").set("selresult", true);
    model.component("comp1").geom("geom1").feature("sphAir").set("selresultshow", "all");

    model.component("comp1").geom("geom1").create("difAir", "Difference");
    model.component("comp1").geom("geom1").feature("difAir").selection("input").set(new String[] { "sphAir" });
    model.component("comp1").geom("geom1").feature("difAir").selection("input2").set(new String[] { "blkVoid" });
    model.component("comp1").geom("geom1").feature("difAir").set("selresult", true);
    model.component("comp1").geom("geom1").feature("difAir").set("selresultshow", "all");

    model.component("comp1").geom("geom1").create("uni1", "Union");
    model.component("comp1").geom("geom1").feature("uni1").selection("input").set(new String[] { "blkRuler", "difAir" });
    model.component("comp1").geom("geom1").feature("uni1").set("intbnd", true);
    model.component("comp1").geom("geom1").run("fin");

    model.component("comp1").selection().create("selRootFace", "Box");
    model.component("comp1").selection("selRootFace").geom("geom1", 2);
    model.component("comp1").selection("selRootFace").set("xmin", "-1e-6[m]");
    model.component("comp1").selection("selRootFace").set("xmax", "1e-6[m]");
    model.component("comp1").selection("selRootFace").set("ymin", "-b/2+1e-6[m]");
    model.component("comp1").selection("selRootFace").set("ymax", "b/2-1e-6[m]");
    model.component("comp1").selection("selRootFace").set("zmin", "-h_ruler/2+1e-6[m]");
    model.component("comp1").selection("selRootFace").set("zmax", "h_ruler/2-1e-6[m]");

    model.component("comp1").selection().create("selImpactFace", "Box");
    model.component("comp1").selection("selImpactFace").geom("geom1", 2);
    model.component("comp1").selection("selImpactFace").set("xmin", "impact_xmin");
    model.component("comp1").selection("selImpactFace").set("xmax", "impact_xmax");
    model.component("comp1").selection("selImpactFace").set("ymin", "impact_ymin");
    model.component("comp1").selection("selImpactFace").set("ymax", "impact_ymax");
    model.component("comp1").selection("selImpactFace").set("zmin", "h_ruler/2-1e-6[m]");
    model.component("comp1").selection("selImpactFace").set("zmax", "h_ruler/2+1e-6[m]");

    model.component("comp1").selection().create("selAcousticDriveBoundary", "Box");
    model.component("comp1").selection("selAcousticDriveBoundary").geom("geom1", 2);
    model.component("comp1").selection("selAcousticDriveBoundary").set("xmin", "-1e-6[m]");
    model.component("comp1").selection("selAcousticDriveBoundary").set("xmax", "L_free+1e-6[m]");
    model.component("comp1").selection("selAcousticDriveBoundary").set("ymin", "-b/2-1e-6[m]");
    model.component("comp1").selection("selAcousticDriveBoundary").set("ymax", "b/2+1e-6[m]");
    model.component("comp1").selection("selAcousticDriveBoundary").set("zmin", "-h_ruler/2-1e-6[m]");
    model.component("comp1").selection("selAcousticDriveBoundary").set("zmax", "h_ruler/2+1e-6[m]");

    model.component("comp1").material().create("matRuler", "Common");
    model.component("comp1").material("matRuler").selection().named("geom1_blkRuler_dom");
    model.component("comp1").material("matRuler").propertyGroup("def").set("density", "rho");
    model.component("comp1").material("matRuler").propertyGroup("def").set("youngsmodulus", "E");
    model.component("comp1").material("matRuler").propertyGroup("def").set("poissonsratio", "nu");

    model.component("comp1").material().create("matAir", "Common");
    model.component("comp1").material("matAir").selection().named("geom1_difAir_dom");
    model.component("comp1").material("matAir").propertyGroup("def").set("density", "rho_air");
    model.component("comp1").material("matAir").propertyGroup("def").set("soundspeed", "c_air");

    model.component("comp1").physics().create("solid", "SolidMechanics", "geom1");
    model.component("comp1").physics("solid").selection().named("geom1_blkRuler_dom");
    model.component("comp1").physics("solid").feature("lemm1").set("E_mat", "userdef");
    model.component("comp1").physics("solid").feature("lemm1").set("E", "E");
    model.component("comp1").physics("solid").feature("lemm1").set("nu_mat", "userdef");
    model.component("comp1").physics("solid").feature("lemm1").set("nu", "nu");
    model.component("comp1").physics("solid").feature("lemm1").set("rho_mat", "userdef");
    model.component("comp1").physics("solid").feature("lemm1").set("rho", "rho");
    model.component("comp1").physics("solid").feature("lemm1").create("dmp1", "Damping", 3);
    model.component("comp1").physics("solid").feature("lemm1").feature("dmp1").selection().named("geom1_blkRuler_dom");
    model.component("comp1").physics("solid").feature("lemm1").feature("dmp1").set("DampingType", "RayleighDamping");
    model.component("comp1").physics("solid").feature("lemm1").feature("dmp1").set("InputParameters", "AlphaBeta");
    model.component("comp1").physics("solid").feature("lemm1").feature("dmp1").set("alpha_dM", "alpha_dM_struct");
    model.component("comp1").physics("solid").feature("lemm1").feature("dmp1").set("beta_dK", "beta_dK_struct");
    model.component("comp1").physics("solid").create("fix1", "Fixed", 2);
    model.component("comp1").physics("solid").feature("fix1").selection().named("selRootFace");
    model.component("comp1").physics("solid").create("bndl1", "BoundaryLoad", 2);
    model.component("comp1").physics("solid").feature("bndl1").selection().named("selImpactFace");
    model.component("comp1").physics("solid").feature("bndl1").set("forceType", "ForceArea");
    model.component("comp1").physics("solid").feature("bndl1").set("forceReferenceArea", new String[] { "0", "0", "fimp_z_area" });

    model.study().create("std1");
    model.study("std1").create("eig", "Eigenfrequency");
    model.study("std1").feature("eig").set("neigsactive", true);
    model.study("std1").feature("eig").set("neigs", "eigen_modes");
    model.study("std1").feature("eig").set("shift", "1000[Hz]");
    model.study("std1").feature("eig").setSolveFor("/physics/solid", true);
    model.study("std1").feature("eig").set("useadvanceddisable", true);
    model.study("std1").feature("eig").set("disabledphysics", new String[] { "solid/bndl1", "solid/lemm1/dmp1" });

    model.component("comp1").mesh().create("mesh1");
    model.component("comp1").mesh("mesh1").automatic(false);
    model.component("comp1").mesh("mesh1").autoMeshSize(__AUTO_MESH_SIZE__);
    model.component("comp1").mesh("mesh1").run();

    model.study("std1").run();

    model.study().create("std2");
    model.study("std2").create("time", "Transient");
    model.study("std2").feature("time").setSolveFor("/physics/solid", true);
    model.study("std2").feature("time").set("tlist", "range(0,time_step,time_end)");
    model.study("std2").run();

    model.component("comp1").physics().create("actd", "TransientPressureAcoustics", "geom1");
    model.component("comp1").physics("actd").selection().named("geom1_difAir_dom");
    model.component("comp1").physics("actd").create("nacc1", "NormalAcceleration", 2);
    model.component("comp1").physics("actd").feature("nacc1").selection().named("selAcousticDriveBoundary");
    model.component("comp1").physics("actd").feature("nacc1").set("Type", "acc");
    model.component("comp1").physics("actd").feature("nacc1").set("acc_src", "userdef");
    model.component("comp1").physics("actd").feature("nacc1").set("acc", new String[] {
      "withsol('sol2',solid.u_ttX,setval(t,t))",
      "withsol('sol2',solid.u_ttY,setval(t,t))",
      "withsol('sol2',solid.u_ttZ,setval(t,t))"
    });
    model.component("comp1").physics("actd").create("swr1", "SphericalWaveRadiation", 2);
    model.component("comp1").physics("actd").feature("swr1").selection().named("geom1_sphAir_bnd");
    model.component("comp1").physics("actd").feature("swr1").set("r0", new String[] { "radiation_source_x", "radiation_source_y", "radiation_source_z" });
    model.component("comp1").mesh("mesh1").feature("ftet1").selection().geom("geom1", 3);
    model.component("comp1").mesh("mesh1").feature("ftet1").selection().all();
    model.component("comp1").mesh("mesh1").run();

    model.study().create("std3");
    model.study("std3").create("time", "Transient");
    model.component("comp1").physics("actd").prop("StudyStep").set("StudyStep", "std3/time");
    model.component("comp1").physics("actd").feature("nacc1").set("StudyStep", "std3/time");
    model.component("comp1").physics("actd").feature("swr1").set("StudyStep", "std3/time");
    model.study("std3").feature("time").setSolveFor("/physics/solid", false);
    model.study("std3").feature("time").setSolveFor("/physics/actd", true);
    model.study("std3").feature("time").set("tlist", "range(0,time_step,time_end)");
    model.study("std3").run();

    exportStandardData(model, "__MODEL_SAVE_PATH__");
    try {
      model.save("__MODEL_SAVE_PATH__");
    } catch (Exception ex) {
      throw new RuntimeException("Failed to save __MODEL_SAVE_PATH__", ex);
    }
    return model;
  }

  public static void main(String[] args) {
    run();
  }

  private static void exportStandardData(Model model, String modelSavePath) {
    File outputRoot = new File(modelSavePath).getParentFile().getParentFile();
    File dataDir = new File(outputRoot, "data");
    String frequencyPath = new File(dataDir, "frequencies.csv").getPath();
    String structurePath = new File(dataDir, "structure_probe_timeseries.csv").getPath();
    String modeShapePath = new File(dataDir, "mode_shapes.csv").getPath();
    String micPath = new File(dataDir, "mic_pressure_timeseries.csv").getPath();
    String impactForcePath = new File(dataDir, "impact_force_timeseries.csv").getPath();
    String tipPath = new File(dataDir, "tip_timeseries.csv").getPath();

    ensureSolutionDataset(model, "dsetEig", "sol1");
    ensureSolutionDataset(model, "dsetStructTime", "sol2");
    ensureSolutionDataset(model, "dsetAirTime", "sol3");
    ensureCutPoint(model, "cptStruct", "dsetStructTime", "L_free-0.5*h_ruler", "0", "0");
    ensureCutPoint(model, "cptTip", "dsetStructTime", "L_free", "0", "0");
    ensureCutPoint(model, "cptMic", "dsetAirTime", "mic_x", "mic_y", "mic_z");

    exportFrequencyCsv(model, frequencyPath);
    exportPointCsv(model, "cptStruct", new String[] { "t", "w" }, new String[] { "t_s", "uz_m" }, structurePath);
    exportModeShapesCsv(model, modeShapePath, 6, __MODE_POINTS__);
    exportPointCsv(model, "cptMic", new String[] { "t", "p" }, new String[] { "t_s", "p_pa" }, micPath);
    exportGlobalCsv(model, "dsetStructTime", new String[] { "t", "force_z_total" }, new String[] { "t_s", "force_z_N" }, impactForcePath);
    exportPointCsv(model, "cptTip", new String[] { "t", "w" }, new String[] { "t_s", "w_m" }, tipPath);
  }

  private static void ensureSolutionDataset(Model model, String tag, String solutionTag) {
    try {
      model.result().dataset(tag);
    } catch (Exception ex) {
      model.result().dataset().create(tag, "Solution");
    }
    model.result().dataset(tag).set("solution", solutionTag);
  }

  private static void ensureCutPoint(Model model, String tag, String dataTag, String pointX, String pointY, String pointZ) {
    try {
      model.result().dataset(tag);
    } catch (Exception ex) {
      model.result().dataset().create(tag, "CutPoint3D");
    }
    model.result().dataset(tag).set("data", dataTag);
    model.result().dataset(tag).set("pointx", pointX);
    model.result().dataset(tag).set("pointy", pointY);
    model.result().dataset(tag).set("pointz", pointZ);
  }

  private static void ensureTable(Model model, String tag) {
    try {
      model.result().table(tag);
    } catch (Exception ex) {
      model.result().table().create(tag, "Table");
    }
  }

  private static void saveMatrixCsv(Model model, String tableTag, String[] headers, double[][] data, String path) {
    ensureTable(model, tableTag);
    model.result().table(tableTag).clearTableData();
    model.result().table(tableTag).setColumnHeaders(headers);
    model.result().table(tableTag).setTableData(data);
    model.result().table(tableTag).saveFile(path);
  }

  private static void exportFrequencyCsv(Model model, String path) {
    String tag = "tmpFreqExport";
    safeRemoveNumerical(model, tag);
    model.result().numerical().create(tag, "EvalGlobal");
    model.result().numerical(tag).set("data", "dsetEig");
    model.result().numerical(tag).set("expr", new String[] { "freq" });

    double[][] raw = model.result().numerical(tag).getReal();
    safeRemoveNumerical(model, tag);
    double[] freq = firstColumn(raw);

    double[][] tableData = new double[freq.length][2];
    for (int i = 0; i < freq.length; i++) {
      tableData[i][0] = i + 1;
      tableData[i][1] = freq[i];
    }
    saveMatrixCsv(model, "tblFreqExport", new String[] { "mode", "freq_hz" }, tableData, path);
  }

  private static void exportPointCsv(Model model, String datasetTag, String[] exprs, String[] headers, String path) {
    String tag = "tmpEval_" + Math.round(1e9 * Math.random());
    safeRemoveNumerical(model, tag);
    model.result().numerical().create(tag, "EvalPoint");
    model.result().numerical(tag).set("data", datasetTag);
    model.result().numerical(tag).set("expr", exprs);

    double[][] raw = model.result().numerical(tag).getReal();
    safeRemoveNumerical(model, tag);
    raw = normalizeByExpressionCount(raw, exprs.length);

    int rowCount = raw[0].length;
    double[][] tableData = new double[rowCount][headers.length];
    for (int i = 0; i < rowCount; i++) {
      for (int j = 0; j < headers.length; j++) {
        tableData[i][j] = raw[j][i];
      }
    }
    saveMatrixCsv(model, "tbl_" + tag, headers, tableData, path);
  }

  private static void exportGlobalCsv(Model model, String datasetTag, String[] exprs, String[] headers, String path) {
    String tag = "tmpGlob_" + Math.round(1e9 * Math.random());
    safeRemoveNumerical(model, tag);
    model.result().numerical().create(tag, "EvalGlobal");
    model.result().numerical(tag).set("data", datasetTag);
    model.result().numerical(tag).set("expr", exprs);

    double[][] raw = model.result().numerical(tag).getReal();
    safeRemoveNumerical(model, tag);
    raw = normalizeByExpressionCount(raw, exprs.length);

    int rowCount = raw[0].length;
    double[][] tableData = new double[rowCount][headers.length];
    for (int i = 0; i < rowCount; i++) {
      for (int j = 0; j < headers.length; j++) {
        tableData[i][j] = raw[j][i];
      }
    }
    saveMatrixCsv(model, "tbl_" + tag, headers, tableData, path);
  }

  private static void exportModeShapesCsv(Model model, String path, int numModes, int nPoints) {
    String datasetTag = "tmpModePt";
    String evalTag = "tmpModeEv";
    safeRemoveDataset(model, datasetTag);
    safeRemoveNumerical(model, evalTag);

    model.result().dataset().create(datasetTag, "CutPoint3D");
    model.result().dataset(datasetTag).set("data", "dsetEig");
    model.result().dataset(datasetTag).set("pointy", "0");
    model.result().dataset(datasetTag).set("pointz", "0");

    model.result().numerical().create(evalTag, "EvalPoint");
    model.result().numerical(evalTag).set("data", datasetTag);
    model.result().numerical(evalTag).set("expr", new String[] { "w" });

    double[][] values = new double[nPoints][numModes];
    for (int i = 0; i < nPoints; i++) {
      double s = (double) i / (double) (nPoints - 1);
      model.result().dataset(datasetTag).set("pointx", String.format(Locale.US, "%.16g*L_free", s));
      double[][] raw = model.result().numerical(evalTag).getReal();
      raw = normalizeModeRow(raw);
      int available = Math.min(numModes, raw[0].length);
      for (int k = 0; k < available; k++) {
        values[i][k] = raw[0][k];
      }
    }

    safeRemoveNumerical(model, evalTag);
    safeRemoveDataset(model, datasetTag);

    double[][] tableData = new double[nPoints][numModes + 1];
    for (int i = 0; i < nPoints; i++) {
      double s = (double) i / (double) (nPoints - 1);
      tableData[i][0] = s;
      for (int k = 0; k < numModes; k++) {
        tableData[i][k + 1] = values[i][k];
      }
    }

    String[] headers = new String[numModes + 1];
    headers[0] = "x_over_L";
    for (int k = 0; k < numModes; k++) {
      headers[k + 1] = "w_mode" + (k + 1);
    }
    saveMatrixCsv(model, "tblModeExport", headers, tableData, path);
  }

  private static double[][] normalizeByExpressionCount(double[][] raw, int exprCount) {
    if (raw.length == exprCount) {
      return raw;
    }
    if (raw.length > 0 && raw[0].length == exprCount) {
      return transpose(raw);
    }
    throw new RuntimeException("Unexpected numerical output shape for expression count " + exprCount);
  }

  private static double[][] normalizeModeRow(double[][] raw) {
    if (raw.length == 1) {
      return raw;
    }
    if (raw.length > 1 && raw[0].length == 1) {
      return transpose(raw);
    }
    return raw;
  }

  private static double[] firstColumn(double[][] raw) {
    if (raw.length == 0) {
      return new double[0];
    }
    if (raw.length == 1) {
      return raw[0];
    }
    double[] out = new double[raw.length];
    for (int i = 0; i < raw.length; i++) {
      out[i] = raw[i][0];
    }
    return out;
  }

  private static double[][] transpose(double[][] raw) {
    if (raw.length == 0) {
      return new double[0][0];
    }
    double[][] out = new double[raw[0].length][raw.length];
    for (int i = 0; i < raw.length; i++) {
      for (int j = 0; j < raw[i].length; j++) {
        out[j][i] = raw[i][j];
      }
    }
    return out;
  }

  private static void safeRemoveNumerical(Model model, String tag) {
    try {
      model.result().numerical().remove(tag);
    } catch (Exception ex) {
    }
  }

  private static void safeRemoveDataset(Model model, String tag) {
    try {
      model.result().dataset().remove(tag);
    } catch (Exception ex) {
    }
  }
}
