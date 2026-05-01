import com.comsol.model.*;
import com.comsol.model.util.*;
import java.io.File;
import java.io.IOException;
import java.util.Locale;

public class Linear_Acoustic_Field {
  public static Model run() {
    ModelUtil.clear();
    Model model = ModelUtil.create("Model");
    model.modelPath(".");
    model.label("linear_acoustic_field.mph");

    model.param().set("L_total", "0.30[m]");
    model.param().set("L_free", "0.18[m]");
    model.param().set("L", "L_free");
    model.param().set("b", "0.03[m]");
    model.param().set("h_beam", "0.001[m]");
    model.param().set("rho", "7850[kg/m^3]");
    model.param().set("E", "200e9[Pa]");
    model.param().set("nu", "0.30");
    model.param().set("root", "ideal_clamp");
    model.param().set("tip", "free");
    model.param().set("excitation_mode", "impact");
    model.param().set("x0", "0.75*L_free");
    model.param().set("use_impulse", "1");
    model.param().set("J", "0.02[N*s]");
    model.param().set("initial_tip_displacement", "0[m]");
    model.param().set("tau_imp", "2e-4[s]");
    model.param().set("pulse_shape", "square_like");
    model.param().set("eigen_modes", "6");
    model.param().set("time_end", "1[s]");
    model.param().set("time_step", "1e-4[s]");
    model.param().set("mesh_numelem", "160");
    model.param().set("use_air_domain", "1");
    model.param().set("air_radius", "0.5[m]");
    model.param().set("mic_distance", "0.06[m]");
    model.param().set("rho_air", "1.225[kg/m^3]");
    model.param().set("c_air", "343[m/s]");

    // __LINEAR_PARAM_BLOCK__

    model.param().set("A", "b*h_beam");
    model.param().set("I", "b*h_beam^3/12");
    model.param().set("t_imp", "5*tau_imp");
    model.param().set("Fimp", "use_impulse*J/(tau_imp*sqrt(pi))*exp(-((t-t_imp)^2)/(tau_imp^2))");

    model.component().create("comp1", true);
    model.component("comp1").geom().create("geom1", 3);
    model.component("comp1").geom("geom1").lengthUnit("m");

    model.component("comp1").geom("geom1").create("pol1", "Polygon");
    model.component("comp1").geom("geom1").feature("pol1").set("source", "table");
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 0, 0);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 0, 1);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 0, 2);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "x0", 1, 0);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 1, 1);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 1, 2);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "L", 2, 0);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 2, 1);
    model.component("comp1").geom("geom1").feature("pol1").setIndex("table", "0", 2, 2);
    model.component("comp1").geom("geom1").run("fin");

    model.component("comp1").physics().create("beam", "HermitianBeam", "geom1");
    model.component("comp1").physics("beam").feature("emm1").set("E_mat", "userdef");
    model.component("comp1").physics("beam").feature("emm1").set("E", "E");
    model.component("comp1").physics("beam").feature("emm1").set("nu_mat", "userdef");
    model.component("comp1").physics("beam").feature("emm1").set("nu", "nu");
    model.component("comp1").physics("beam").feature("emm1").set("rho_mat", "userdef");
    model.component("comp1").physics("beam").feature("emm1").set("rho", "rho");
    model.component("comp1").physics("beam").feature("csd1").set("SectionType", "RectangularSection");
    model.component("comp1").physics("beam").feature("csd1").set("hy_rect", "b");
    model.component("comp1").physics("beam").feature("csd1").set("hz_rect", "h_beam");

    model.component("comp1").physics("beam").create("fix1", "Fixed", 0);
    model.component("comp1").physics("beam").feature("fix1").selection().set(1);

    model.component("comp1").physics("beam").create("plimp", "PointLoad", 0);
    model.component("comp1").physics("beam").feature("plimp").selection().set(2);
    model.component("comp1").physics("beam").feature("plimp").set("forcePoint", new String[]{"0", "0", "Fimp"});

    model.component("comp1").mesh().create("mesh1");
    model.component("comp1").mesh("mesh1").create("edg1", "Edge");
    model.component("comp1").mesh("mesh1").feature("edg1").selection().set(new int[]{1, 2});
    model.component("comp1").mesh("mesh1").feature("edg1").create("dis1", "Distribution");
    model.component("comp1").mesh("mesh1").feature("edg1").feature("dis1").selection().set(new int[]{1, 2});
    model.component("comp1").mesh("mesh1").feature("edg1").feature("dis1").set("numelem", "mesh_numelem");
    model.component("comp1").mesh("mesh1").run();

    model.study().create("std1");
    model.study("std1").create("eig", "Eigenfrequency");
    model.study("std1").feature("eig").set("neigsactive", true);
    model.study("std1").feature("eig").set("neigs", "eigen_modes");
    model.study("std1").feature("eig").set("shift", "50[Hz]");
    model.study("std1").feature("eig").setSolveFor("/physics/beam", true);
    model.study("std1").feature("eig").set("useadvanceddisable", true);
    model.study("std1").feature("eig").set("disabledphysics", new String[]{"beam/plimp"});

    model.study().create("std2");
    model.study("std2").create("time", "Transient");
    model.study("std2").feature("time").setSolveFor("/physics/beam", true);
    model.study("std2").feature("time").set("tlist", "range(0,time_step,time_end)");

    model.study("std1").run();
    model.study("std2").run();
    exportStandardData(model, "__MODEL_SAVE_PATH__");

    try {
      model.save("__MODEL_SAVE_PATH__");
    } catch (java.io.IOException e) {
      throw new RuntimeException("Failed to save __MODEL_SAVE_PATH__", e);
    }
    return model;
  }

  public static void main(String[] args) {
    run();
  }

  private static void exportStandardData(Model model, String modelSavePath) {
    File outputRoot = new File(modelSavePath).getParentFile().getParentFile();
    File dataDir = new File(outputRoot, "data");

    ensureSolutionDataset(model, "dsetEig", "sol1");
    ensureSolutionDataset(model, "dsetTime", "sol2");
    ensureCutPoint(model, "cptTip", "dsetTime", "L", "0", "0");
    ensureCutPoint(model, "cptMic", "dsetTime", "L", "0", "0");

    exportFrequencyCsv(model, new File(dataDir, "frequencies.csv").getAbsolutePath());
    exportPointCsv(model, "cptTip", new String[]{"t", "w"}, new String[]{"t_s", "w_m"}, new File(dataDir, "tip_timeseries.csv").getAbsolutePath());
    exportModeShapesCsv(model, new File(dataDir, "mode_shapes.csv").getAbsolutePath(), 6, 241);
    exportPointCsv(
      model,
      "cptMic",
      new String[]{"t", "if(use_air_domain,rho_air*A/(4*pi*mic_distance)*d(d(w,t),t),0[Pa])"},
      new String[]{"t_s", "p_pa"},
      new File(dataDir, "mic_pressure_timeseries.csv").getAbsolutePath());
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
    model.result().numerical(tag).set("expr", new String[]{"freq"});

    double[][] raw = model.result().numerical(tag).getReal();
    safeRemoveNumerical(model, tag);
    double[] freq = firstColumn(raw);

    double[][] tableData = new double[freq.length][2];
    for (int i = 0; i < freq.length; i++) {
      tableData[i][0] = i + 1;
      tableData[i][1] = freq[i];
    }
    saveMatrixCsv(model, "tblFreqExport", new String[]{"mode", "freq_hz"}, tableData, path);
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
    model.result().numerical(evalTag).set("expr", new String[]{"w"});

    double[][] values = new double[nPoints][numModes];
    for (int i = 0; i < nPoints; i++) {
      double s = (double) i / (double) (nPoints - 1);
      model.result().dataset(datasetTag).set("pointx", String.format(Locale.US, "%.16g*L", s));
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
