import { ThemeProvider } from "styled-components/native";

import { Routes } from "@routes/index";
import theme from "@theme/index";

import { useFonts } from "expo-font";

export default function App() {
  const [fontsLoaded] = useFonts({
    "Glacial Indifference": require("@assets/fonts/GlacialIndifference-Regular.otf"),
    "Glacial Indifference-Bold": require("@assets/fonts/GlacialIndifference-Bold.otf"),
    "Glacial Indifference-Italic": require("@assets/fonts/GlacialIndifference-Italic.otf"),
  });

  if (!fontsLoaded) {
    return null;
  }

  return (
    <ThemeProvider theme={theme}>
      <Routes />
    </ThemeProvider>
  );
}
