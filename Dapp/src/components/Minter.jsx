import React, { useState } from "react";
import { ethers } from "ethers";
import axios from "axios";
// Icons
import { BiImageAdd, BiEdit, BiLoaderAlt } from "react-icons/bi";
// Contract
import { abi } from "./../contract/contractAbi";
import { address } from "./../contract/contractAddress";
// Popup
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

function Minter({ wallet }) {
  // const [formInput, setFormInput] = useState({
  //   name: "",
  //   description: "",
  //   external_url: "",
  //   image: "",
  //   animation_url: "",
  // });
  const [mintingStatus, setMintingStatus] = useState(false);
  // console.log(process.env.React_App_PINATA_APP_KEY);
  // 1.Upload file [i.e. Image] to Pinata
  // const handleUploadImage = async (event) => {
  //   const formData = new FormData();
  //   formData.append("file", event.target.files[0]);
  //   toast.promise(
  //     axios({
  //       method: "post",
  //       url: "https://api.pinata.cloud/pinning/pinFileToIPFS",
  //       data: formData,
  //       headers: {
  //         pinata_api_key: `${process.env.REACT_APP_PINATA_API_KEY}`,
  //         pinata_secret_api_key: `${process.env.REACT_APP_PINATA_API_SECRET}`,
  //         "Content-Type": "multipart/form-data",
  //       },
  //     })
  //       .then((res) => {
  //         setFormInput({
  //           ...formInput,
  //           image: `https://gateway.pinata.cloud/ipfs/${res.data.IpfsHash}`,
  //         });
  //       })
  //       .catch((err) => {
  //         toast.error("Error in uploading Image to IPFS: ");
  //         toast.error(err);
  //       }),
  //     {
  //       pending: "Image is uploading to IPFS...",
  //       success: "Upload Image Successfully 👌",
  //       error: "Promise rejected 🤯",
  //     }
  //   );
  // };
  // 2.Creating Item and Saving it to IPFS
  // const handleCreateMetadata = async () => {
  //   const { name, description, external_url, image, animation_url } = formInput;
  //   if (!name || !description || !image || !animation_url || !external_url) {
  //     toast.error("Please fill all the fields");
  //     return;
  //   }
  //   setMintingStatus(true);
  //   const metadata = {
  //     description: description,
  //     external_url: external_url,
  //     image: image,
  //     animation_url: animation_url,
  //     name: name,
  //   };
  //   setFormInput({
  //     name: "",
  //     description: "",
  //     external_url: "",
  //     image: "",
  //     animation_url: "",
  //   });
  //   // Save Token Metadata to IPFS
  //   toast.promise(
  //     axios({
  //       method: "post",
  //       url: "https://api.pinata.cloud/pinning/pinJSONToIPFS",
  //       data: JSON.stringify(metadata),
  //       headers: {
  //         pinata_api_key: `${process.env.REACT_APP_PINATA_API_KEY}`,
  //         pinata_secret_api_key: `${process.env.REACT_APP_PINATA_API_SECRET}`,
  //         "Content-Type": "application/json",
  //       },
  //     })
  //       .then((res) => {
  //         mintItem(`https://gateway.pinata.cloud/ipfs/${res.data.IpfsHash}`);
  //         setMintingStatus(false);
  //       })
  //       .catch((err) => {
  //         toast.error("Error Uploading Metadata to IPFS: Metadata ");
  //         toast.error(err);
  //         setMintingStatus(false);
  //       }),
  //     {
  //       pending: "Uploading Metadata to IPFS",
  //       success: "Uploaded Metadata Successfully 👌",
  //       error: "Promise rejected 🤯",
  //     }
  //   );
  // };
  // 3.Mint item
  const mintItem = async (metadataURI) => {
    // console.log("URL", metadataURI);
    // console.log("hii");
    let contract = new ethers.Contract(address, abi, wallet?.signer);
    console.log(contract);
    console.log(await contract.owner());
    // let c = ethers.BigNumber.from(await contract.RESERVED_AMOUNT()).toString();
    // console.log(c);

    toast.promise(
      contract.mintToTeam(wallet?.address, 1).then((transaction) => {
        toast.promise(
          transaction
            .wait()
            .then((tx) => {
              toast.info(tx);
              setMintingStatus(false);
            })
            .catch((err) => {
              toast.error("Error in Minting Token:", err);
            }),
          {
            pending: "Minting in Process...",
            success: "Mint Successfully 👌",
            error: "Promise rejected 🤯",
          }
        );
      }),
      {
        pending: "Waiting to Sign Transaction...",
        success: "Transaction Signed... 👌",
        error: "Transaction Rejected 🤯",
      }
    );
  };
  // FromData
  // console.log("FormData: ", formInput);
  return (
    <>
      <ToastContainer />
      <div className="flex flex-col md:flex-row px-3 pb-3 h-[calc(h-screen - 12rem)]">
        {/* <div className="w-full md:w-5/12 h-auto md:pr-3"></div> */}
        <div className="w-full h-[70vh] flex justify-center items-center">
          <button
            onClick={mintItem}
            className="bg-back border-l-4 border-b-2 border-bord md:px-12 px-4 py-2 mr-3 rounded-xl"
          >
            Mint
          </button>
        </div>
      </div>
    </>
  );
}

export default Minter;
