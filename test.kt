import android.util.Pair
import java.util.List

fun test(attrs: List<Pair<String, String>>) {
    val a = attrs.find { it.first == "type" }?.second
}
