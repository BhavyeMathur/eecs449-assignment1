"""Reusable Daybook mobile button."""

import from "@jac/mobui" { Pressable, Text }
import from ..theme { C }

def:pub Button(
    label: str,
    onPress: Callable[[], None],
    variant: str = "primary",
    disabled: bool = False
) -> JsxElement {
    base_styles = {
        flex: 1,
        paddingVertical: 12,
        paddingHorizontal: 16,
        borderRadius: 12,
        alignItems: "center",
        justifyContent: "center",
        opacity: 0.5 if disabled else 1.0
    };

    variant_styles = {
        "primary": {backgroundColor: C.accent},
        "secondary": {backgroundColor: C.surfaceAlt, borderWidth: 1, borderColor: C.border}
    };

    label_styles = {
        color: C.onAccent if variant == "primary" else C.text,
        fontSize: 14,
        fontWeight: "600"
    };

    <Pressable
        style={[base_styles, variant_styles[variant]]}
        onPress={onPress}
        disabled={disabled}
    >
        <Text style={label_styles}>{label}</Text>
    </Pressable>
}
