import com.comsol.model.*;
import com.comsol.model.util.*;

public class Linear_Impact_Response {
  public static Model run() {
    ModelUtil.clear();
    Model model = ModelUtil.create("Model");
    model.modelPath(".");
    model.label("linear_impact_response.mph");

    model.param().set("L_total", "0.30[m]");
    model.param().set("L_free", "0.18[m]");
    model.param().set("L", "L_free");
    model.param().set("b", "0.03[m]");
    model.param().set("h_beam", "0.0010[m]");
    model.param().set("rho", "7850[kg/m^3]");
    model.param().set("E", "200e9[Pa]");
    model.param().set("nu", "0.30");
    model.param().set("root", "ideal_clamp");
    model.param().set("tip", "free");
    model.param().set("excitation_mode", "impact");
    model.param().set("x0", "0.75*L_free");
    model.param().set("use_impulse", "1");
    model.param().set("J", "0.02[N*s]");
    model.param().set("tau_imp", "2e-4[s]");
    model.param().set("pulse_shape", "square_like");
    model.param().set("t_imp", "5*tau_imp");
    model.param().set("Fimp", "use_impulse*J/(tau_imp*sqrt(pi))*exp(-((t-t_imp)^2)/(tau_imp^2))");
    model.param().set("eigen_modes", "6");
    model.param().set("time_end", "1[s]");
    model.param().set("time_step", "1e-4[s]");

    // __LINEAR_PARAM_BLOCK__

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
}
