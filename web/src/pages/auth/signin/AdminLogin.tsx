import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Box,
  Button,
  Center,
  FormControl,
  Input,
  InputGroup,
  InputRightElement,
  VStack,
  useToast,
  Text,
} from "@chakra-ui/react";
import { ViewIcon, ViewOffIcon } from "@chakra-ui/icons";
import { t } from "i18next";

import { Logo } from "@/components/LogoIcon";
import useAuthStore from "@/pages/auth/store";

export default function AdminLogin() {
  const navigate = useNavigate();
  const toast = useToast();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const { passwordSignIn } = useAuthStore();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!username || !password) {
      toast({
        title: t("AuthPanel.EmptyUsernameOrPassword"),
        status: "warning",
        duration: 3000,
      });
      return;
    }

    setIsLoading(true);
    
    try {
      const res = await passwordSignIn({
        username,
        password,
      });
      
      if (res?.data) {
        navigate("/dashboard");
      }
    } catch (error: any) {
      toast({
        title: error?.response?.data?.message || t("AuthPanel.LoginFailed"),
        status: "error",
        duration: 3000,
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Center minH="100vh" bg="gray.50">
      <Box
        w="400px"
        p={8}
        bg="white"
        borderRadius="lg"
        boxShadow="lg"
      >
        <VStack spacing={6}>
          <Logo size="60px" outerColor="#33BABB" innerColor="white" />
          
          <Text fontSize="2xl" fontWeight="bold" color="gray.700">
            Data Plane Admin
          </Text>

          <form onSubmit={handleSubmit} style={{ width: "100%" }}>
            <VStack spacing={4} w="100%">
              <FormControl isRequired>
                <Input
                  size="lg"
                  placeholder={t("AuthPanel.Username")}
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  autoComplete="username"
                />
              </FormControl>

              <FormControl isRequired>
                <InputGroup size="lg">
                  <Input
                    type={showPassword ? "text" : "password"}
                    placeholder={t("AuthPanel.Password")}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    autoComplete="current-password"
                    pr="4.5rem"
                  />
                  <InputRightElement width="3rem">
                    <Button
                      h="1.75rem"
                      size="sm"
                      variant="ghost"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      {showPassword ? <ViewOffIcon /> : <ViewIcon />}
                    </Button>
                  </InputRightElement>
                </InputGroup>
              </FormControl>

              <Button
                type="submit"
                colorScheme="teal"
                size="lg"
                width="100%"
                isLoading={isLoading}
                loadingText={t("AuthPanel.Logging")}
              >
                {t("AuthPanel.Login")}
              </Button>
            </VStack>
          </form>
        </VStack>
      </Box>
    </Center>
  );
}